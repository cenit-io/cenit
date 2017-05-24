require 'nokogiri'

module Setup
  class Flow
    # = Flow
    #
    # Defines how data is processed by the execution of one or more actions.

    include ReqRejValidator
    include ShareWithBindings
    include NamespaceNamed
    include TriggersFormatter
    include ThreadAware
    include ModelConfigurable
    include RailsAdmin::Models::Setup::FlowAdmin

    build_in_data_type.referenced_by(:namespace, :name)
    build_in_data_type.and(
      properties: {
        active: {
          type: 'boolean',
          default: true
        },
        notify_request: {
          type: 'boolean',
          default: false
        },
        notify_response: {
          type: 'boolean',
          default: false
        },
        discard_events: {
          type: 'boolean'
        },
        auto_retry: {
          type: 'string',
          enum: Setup::Task.auto_retry_enum.collect(&:to_s)
        }
      }
    )

    binding_belongs_to :event, class_name: Setup::Event.to_s, inverse_of: nil

    belongs_to :translator, class_name: Setup::Translator.to_s, inverse_of: nil
    belongs_to :custom_data_type, class_name: Setup::DataType.to_s, inverse_of: nil
    field :nil_data_type, type: Boolean
    field :data_type_scope, type: String
    field :scope_filter, type: String
    belongs_to :scope_evaluator, class_name: Setup::Algorithm.to_s, inverse_of: nil
    field :lot_size, type: Integer

    belongs_to :webhook, class_name: Setup::Webhook.to_s, inverse_of: nil
    binding_belongs_to :authorization, class_name: Setup::Authorization.to_s, inverse_of: nil
    binding_belongs_to :connection_role, class_name: Setup::ConnectionRole.to_s, inverse_of: nil
    belongs_to :before_submit, class_name: Setup::Algorithm.to_s, inverse_of: nil

    belongs_to :response_translator, class_name: Setup::Translator.to_s, inverse_of: nil
    belongs_to :response_data_type, class_name: Setup::DataType.to_s, inverse_of: nil

    has_and_belongs_to_many :after_process_callbacks, class_name: Setup::Algorithm.to_s, inverse_of: nil

    validates_numericality_in_presence_of :lot_size, greater_than_or_equal_to: 1

    config_with Setup::FlowConfig

    before_save :validates_configuration, :check_scheduler

    after_save :schedule_task

    def validates_configuration
      format_triggers_on(:scope_filter) if scope_filter.present?
      unless requires(:name, :translator)
        if event.present?
          unless translator.type == :Import || requires(:data_type_scope)
            if scope_symbol == :event_source &&
              !(event.is_a?(Setup::Observer) && event.data_type == data_type)
              errors.add(:event, 'not compatible with data type scope')
            end
          end
        elsif scope_symbol == :event_source
          if persisted?
            requires(:event)
          else
            rejects(:data_type_scope)
          end
        end
        if translator.data_type.nil?
          requires(:custom_data_type) if translator.type == :Conversion && event.present?
        else
          rejects(:custom_data_type)
        end
        if translator.type == :Import
          rejects(:data_type_scope, :scope_filter, :scope_evaluator)
        else
          case scope_symbol
          when :filtered
            format_triggers_on(:scope_filter, true)
            rejects(:scope_evaluator)
          when :evaluation
            unless requires(:scope_evaluator)
              errors.add(:scope_evaluator, 'must receive one parameter') unless scope_evaluator.parameters.count == 1
            end
            rejects(:scope_filter)
          else
            rejects(:scope_filter, :scope_evaluator)
          end
        end
        if [:Import, :Export].include?(translator.type)
          requires(:webhook)
          if translator.type == :Import
            unless before_submit.nil? || before_submit.parameters.count == 1 || before_submit.parameters.count == 2
              errors.add(:before_submit, 'must receive one or two parameter')
            end
          else
            rejects(:before_submit)
          end
        else
          rejects(:before_submit, :connection_role, :authorization, :webhook, :notify_request, :notify_response)
        end

        if translator.type == :Export
          if response_translator.present?
            if response_translator.type == :Import
              if response_translator.data_type
                rejects(:response_data_type)
              else
                requires(:response_data_type)
              end
            else
              errors.add(:response_translator, 'is not an import translator')
            end
          else
            rejects(:response_data_type, :discard_events)
          end
          rejects(:data_type_scope) if data_type.nil?
        else
          rejects(:lot_size, :response_translator, :response_data_type)
        end
      end
      if (bad_callbacks = after_process_callbacks.select { |c| c.parameters.count != 1 }).present?
        errors.add(:after_process_callbacks, "contains algorithms with unexpected parameter size: #{bad_callbacks.collect(&:custom_title).to_sentence}")
      end
      errors.blank?
    end

    def reject_message(field = nil)
      case field
      when :custom_data_type
        'is not allowed since translator already defines a data type'
      when :data_type_scope
        'is not allowed for import translators'
      when :response_data_type
        response_translator.present? ? 'is not allowed since response translator already defines a data type' : "can't be defined until response translator"
      when :discard_events
        "can't be defined until response translator"
      when :lot_size, :response_translator
        'is not allowed for non export translators'
      else
        super
      end
    end

    def with(options)
      if options && (data_type = options.delete(:data_type))
        using_data_type(data_type)
      end
      super
    end

    def own_data_type
      (translator && translator.data_type) || custom_data_type
    end

    def using_data_type(data_type)
      if (own_dt = own_data_type) && own_dt != data_type
        fail "Illegal data type option #{data_type.custom_title}, a flow own data type #{flow_data_type} is already configured"
      else
        @_data_type = data_type if data_type
      end
    end

    def data_type
      @_data_type || own_data_type
    end

    def data_type_scope_enum
      enum = []
      if data_type
        enum << 'Event source' if event && event.try(:data_type) == data_type
        enum << "All #{data_type.title.downcase.to_plural}"
        enum << 'Filter'
        enum << 'Evaluator'
      else
        enum << nil
      end
      enum
    end

    def auto_retry_enum
      Setup::Task.auto_retry_enum
    end

    def ready_to_save?
      shared? ||
        ((t = translator).present? &&
          (event.blank? || data_type_scope.present? || t.type == :Import) &&
          ([:Export, :Import].exclude?(t.type) || webhook.present?))
    end

    def can_be_restarted?
      event || translator
    end

    def join_process(message={})
      if (task_token = Thread.current[:task_token]) &&
        (thread_token = ThreadToken.where(token: task_token).first) &&
        (current_task = Task.where(thread_token: thread_token).first)
        process(message) do |task|
          task.join(current_task)
        end
      else
        process(message)
      end
    end

    def process(message={}, &block)
      executing_id, execution_graph = current_thread_cache.last || [nil, {}]
      if executing_id
        execution_graph[executing_id] ||= []
        adjacency_list = execution_graph[executing_id]
        adjacency_list << id.to_s if adjacency_list.exclude?(id.to_s)
      end
      result =
        if (cycle = cyclic_execution(execution_graph, executing_id))
          cycle = cycle.collect { |id| ((flow = Setup::Flow.where(id: id).first) && flow.custom_title) || id }
          Setup::SystemNotification.create_with(message: "Cyclic flow execution: #{cycle.to_a.join(' -> ')}",
                                                attachment: {
                                            filename: 'execution_graph.json',
                                            contentType: 'application/json',
                                            body: JSON.pretty_generate(execution_graph)
                                          })
        else
          message = message.merge(flow_id: id.to_s,
                                  tirgger_flow_id: executing_id,
                                  execution_graph: execution_graph,
                                  auto_retry: auto_retry)
          if (data_type = message.delete(:data_type))
            message[:data_type_id] = data_type.capataz_slave.id.to_s # TODO Remove capataz_slave when fixing capataz rewriter for Hash call arguments
          end
          Setup::FlowExecution.process(message, &block)
        end
      save
      result
    end

    def translate(message, &block)
      if translator.present?
        begin
          flow_execution = current_thread_cache
          flow_execution << [id.to_s, message[:execution_graph] || {}]
          data_type = Setup::BuildInDataType[message[:data_type_id]] ||
            Setup::DataType.where(id: message[:data_type_id]).first
          using_data_type(data_type) if data_type
          send("translate_#{translator.type.to_s.downcase}", message, &block)
          after_process_callbacks.each do |callback|
            begin
              callback.run(message[:task])
            rescue Exception => ex
              Setup::SystemNotification.create(message: "Error executing after process callback #{callback.custom_title}: #{ex.message}")
            end
          end
        ensure
          flow_execution.pop
        end
      else
        yield(message: "Flow translator can't be blank")
      end
    end

    def scope_symbol
      if data_type_scope.present?
        if data_type_scope.start_with?('Event')
          :event_source
        elsif data_type_scope.start_with?('Filter')
          :filtered
        elsif data_type_scope.start_with?('Eval')
          :evaluation
        else
          :all
        end
      else
        nil
      end
    end

    class << self
      def default_thread_value
        []
      end
    end

    private

    def check_scheduler
      if @scheduler_checked.nil?
        @scheduler_checked = changed_attributes.has_key?(:event_id.to_s) && event.is_a?(Setup::Scheduler)
      else
        @scheduler_checked = false
      end
      true
    end

    def schedule_task
      process(scheduler: event) if @scheduler_checked && event.activated
    end

    def cyclic_execution(execution_graph, start_id, cycle = [])
      if cycle.include?(start_id)
        cycle << start_id
        return cycle
      elsif (adjacency_list = execution_graph[start_id])
        cycle << start_id
        adjacency_list.each { |id| return cycle if cyclic_execution(execution_graph, id, cycle) }
        cycle.pop
      end
      false
    end

    def simple_translate(message, &block)
      object_ids = ((obj_id = message[:source_id]) && [obj_id]) || source_ids_from(message)
      task = message[:task]
      if translator.source_handler
        begin
          translator.run(object_ids: object_ids, discard_events: discard_events, task: task, data_type: data_type)
        rescue Exception => ex
          msg = "Error source handling translation of records of type '#{data_type.custom_title}' with '#{translator.custom_title}': #{ex.message}"
          if task
            task.notify message: msg
          else
            fail msg
          end
        end
      else
        if object_ids
          data_type.records_model.any_in(id: object_ids)
        else
          data_type.records_model.all
        end.each do |obj|
          begin
            translator.run(object: obj, discard_events: discard_events, task: message[:task], data_type: data_type)
          rescue Exception => ex
            msg = "Error translating record with ID '#{obj.id}' of type '#{data_type.custom_title}' when executing '#{translator.custom_title}': #{ex.message}"
            if task
              task.notify message: msg
            else
              fail msg
            end
          end
        end
      end
    rescue Exception => ex
      block.yield(ex) if block
    end

    def translate_conversion(message, &block)
      simple_translate(message, &block)
    end

    def translate_update(message, &block)
      simple_translate(message, &block)
    end

    def translate_import(message, &block)
      options =
        {
          headers: message['headers'] || {},
          parameters: message['parameters'] || {},
          template_parameters: message['template_parameters'] || {},
          notify_request: notify_request,
          notify_response: notify_response,
          verbose_response: true,
          data_type: data_type
        }
      if before_submit
        if before_submit.parameters.count == 1
          before_submit.run(options)
        elsif before_submit.parameters.count == 2
          before_submit.run([options, message[:task]])
        end
      end
      verbose_response =
        webhook.target.with(connection_role).and(authorization).submit(options) do |response, template_parameters|
          translator.run(target_data_type: data_type,
                         data: response.body,
                         discard_events: discard_events,
                         parameters: template_parameters,
                         headers: response.headers.to_hash,
                         statusCode: response.code,
                         task: message[:task])
        end
      if auto_retry == :automatic
        if (http_response = verbose_response[:http_response])
          if (200...299).exclude?(http_response.code)
            fail unsuccessful_response(http_response, message)
          end
        else
          fail 'Connection error'
        end
      end
    end

    def translate_export(message, &block)
      limit = translator.bulk_source ? lot_size || 1000 : 1
      max =
        if (object_ids = source_ids_from(message))
          object_ids.size
        elsif data_type
          data_type.count
        else
          0
        end - (scope_symbol ? 1 : 0)
      translation_options = nil
      connections_present = true
      0.step(max, limit) do |offset|
        next unless connections_present
        verbose_response =
          webhook.target.with(connection_role).and(authorization).submit ->(template_parameters) {
            translation_options =
              {
                object_ids: object_ids,
                source_data_type: data_type,
                offset: offset,
                limit: limit,
                discard_events: discard_events,
                parameters: template_parameters,
                task: message[:task]
              }
            translator.run(translation_options)
          },
                                                                         contentType: translator.mime_type,
                                                                         notify_request: notify_request,
                                                                         request_attachment: ->(attachment) do
                                                                           attachment[:filename] = ((data_type && data_type.title) || translator.name).collectionize +
                                                                             attachment[:filename] +
                                                                             ((ext = translator.file_extension).present? ? ".#{ext}" : '')
                                                                           attachment
                                                                         end,
                                                                         notify_response: notify_response,
                                                                         verbose_response: true do |response|
            if response_translator #&& response.code == 200
              response_translator.run(translation_options.merge(target_data_type: response_translator.data_type || response_data_type,
                                                                data: response.body,
                                                                headers: response.headers.to_hash,
                                                                statusCode: response.code, #TODO Remove after deprecation migration
                                                                response_code: response.code,
                                                                requester_response: response.requester_response?))
            end
            true
          end
        if auto_retry == :automatic
          if (http_response = verbose_response[:http_response])
            if (200...299).exclude?(http_response.code)
              fail unsuccessful_response(http_response, message)
            end
          else
            fail 'Connection error'
          end
        end
        connections_present = verbose_response[:connections_present]
      end
    end

    def unsuccessful_response(http_response, task_msg)
      {
        error: 'Unsuccessful response code',
        code: http_response.code,
        user: ::User.current.label,
        user_id: ::User.current.id,
        tenant: Account.current.label,
        tenant_id: Account.current.id,
        task: task_msg,
        flow: to_hash,
        flow_attributes: attributes
      }.to_json
    end

    def attachment_from(http_response)
      file_extension = ((types =MIME::Types[http_response.content_type]).present? &&
        (ext = types.first.extensions.first).present? && '.' + ext) || ''
      {
        filename: http_response.object_id.to_s + file_extension,
        contentType: http_response.content_type,
        body: http_response.body
      } if notify_response && http_response
    end

    def source_ids_from(message)
      if (object_ids = message[:object_ids])
        object_ids
      elsif scope_symbol == :event_source && id = message[:source_id]
        [id]
      elsif scope_symbol == :filtered
        data_type.records_model.all.select { |record| field_triggers_apply_to?(:scope_filter, record) }.collect(&:id)
      elsif scope_symbol == :evaluation
        data_type.records_model.all.select { |record| scope_evaluator.run(record).present? }.collect(&:id)
      else
        nil
      end
    end

  end
end
