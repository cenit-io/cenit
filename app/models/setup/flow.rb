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

    field :description, type: String

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
              if scope_evaluator.parameters.size == 1
                unless scope_evaluator.parameters.first.name == 'scope'
                  errors.add(:scope_evaluator, "argument name should be 'scope'")
                end
              else
                errors.add(:scope_evaluator, 'must receive one parameter')
              end
            end
            rejects(:scope_filter)
          else
            rejects(:scope_filter, :scope_evaluator)
          end
        end
        if [:Import, :Export].include?(translator.type)
          requires(:webhook)
          if translator.type == :Import
            unless before_submit.nil? || before_submit.parameters.size == 1 || before_submit.parameters.size == 2
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
      if (bad_callbacks = after_process_callbacks.select { |c| c.parameters.size != 1 }).present?
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

    def join_process(message = {}, join_task = Task.current)
      if join_task
        process(message) do |task|
          task.join(join_task)
        end
      else
        process(message)
      end
    end

    def process(message = {}, &block)
      execution_graph = current_thread_cache.last || {}
      if (trigger_flow_id = execution_graph['trigger_flow_id'])
        execution_graph[trigger_flow_id] ||= []
        adjacency_list = execution_graph[trigger_flow_id]
        adjacency_list << id.to_s if adjacency_list.exclude?(id.to_s)
      end
      message = message.merge(flow_id: id.to_s,
                              execution_graph: execution_graph,
                              auto_retry: auto_retry)
      if (data_type = message.delete(:data_type)).is_a?(Setup::DataType)
        message[:data_type_id] = data_type.capataz_slave.id.to_s # TODO Remove capataz_slave when fixing capataz rewriter for Hash call arguments
      end
      if (authorization = message.delete(:authorization)).is_a?(Setup::Authorization)
        message[:authorization_id] = authorization.capataz_slave.id.to_s # TODO Remove capataz_slave when fixing capataz rewriter for Hash call arguments
      end
      if (connection = message.delete(:connection)).is_a?(Setup::Connection)
        message[:connection_id] = connection.capataz_slave.id.to_s # TODO Remove capataz_slave when fixing capataz rewriter for Hash call arguments
      end
      result = Setup::FlowExecution.process(message, &block)
      save
      result
    end

    def translate(message, &block)
      if translator.present?
        begin
          flow_execution = current_thread_cache
          flow_execution << (message[:execution_graph] || {}).merge('trigger_flow_id' => id.to_s)
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

    def sources(message)
      object_ids = ((obj_id = message[:source_id]) && [obj_id]) || source_ids_from(message)
      if object_ids
        data_type.records_model.any_in(id: object_ids)
      else
        data_type.records_model.all
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

    def simple_translate(message, &block)
      unless (options = message[:options]).is_a?(Hash)
        options = {}
      end
      object_ids = ((obj_id = message[:source_id]) && [obj_id]) || source_ids_from(message)
      task = message[:task]
      if translator.try(:source_handler)
        begin
          translator.run(object_ids: object_ids, discard_events: discard_events, task: task, data_type: data_type, options: options)
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
            translator.run(object: obj, discard_events: discard_events, task: message[:task], data_type: data_type, options: options)
          rescue Exception => ex
            msg = "Error translating record with ID '#{obj.id}' of type '#{data_type.custom_title}' when executing '#{translator.custom_title}': #{ex.message}"
            if task
              task.notify(message: msg)
              task.notify(ex)
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
      connection = options[:connection] || (
      (connection_id = options[:connection_id] || message[:connection_id]) && Setup::Connection.where(id: connection_id).first
      ) || self.connection_role
      authorization = options[:authorization] || (
      (authorization_id = options[:authorization_id] || message[:authorization_id]) && Setup::Authorization.where(id: authorization_id).first
      ) || self.authorization
      verbose_response =
        webhook.target.with(connection).and(authorization).submit(options) do |response, template_parameters|
          translator.run(target_data_type: data_type,
                         data: response.body,
                         discard_events: discard_events,
                         parameters: template_parameters,
                         headers: response.headers.to_hash,
                         statusCode: response.code,
                         response_code: response.code,
                         task: message[:task])
        end
      if auto_retry == :automatic
        if (response = verbose_response[:response])
          unless response.success?
            fail unsuccessful_response(response, message)
          end
        else
          fail 'Connection error'
        end
      end
    end

    def translate_export(message, &block)
      limit = translator.try(:bulk_source) ? lot_size || 1000 : 1
      max =
        if (object_ids = source_ids_from(message))
          object_ids.size
        elsif data_type
          data_type.count
        else
          0
        end - 1
      translation_options = nil
      connections_present = true
      records_processed = false
      connection = (
      (connection_id = message[:connection_id]) && Setup::Connection.where(id: connection_id).first
      ) || self.connection_role
      authorization = (
      (authorization_id = message[:authorization_id]) && Setup::Authorization.where(id: authorization_id).first
      ) || self.authorization
      0.step(max, limit) do |offset|
        records_processed = true
        next unless connections_present
        verbose_response =
          webhook.target.with(connection).and(authorization).submit(
            ->(template_parameters) {
              translation_options =
                {
                  object_ids: object_ids,
                  source_data_type: data_type,
                  offset: offset,
                  limit: limit,
                  discard_events: discard_events,
                  template_parameters: template_parameters,
                  parameters: template_parameters,
                  task: message[:task]
                }
              if (options = message[:template_options]).is_a?(Hash)
                translation_options[:options] = options
              end
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
            verbose_response: true,
            headers: message['headers'] || {},
            parameters: message['parameters'] || {},
            template_parameters: message['template_parameters'] || {}
          ) do |response|
            if response_translator #&& response.code == 200
              response_translator.run(translation_options.merge(
                target_data_type: response_translator.data_type || response_data_type,
                data: response.body,
                headers: response.headers.to_hash,
                statusCode: response.code, #TODO Remove after deprecation migration
                response_code: response.code,
                requester_response: response.requester_response?)
              )
            end
            true
          end
        if auto_retry == :automatic
          if (response = verbose_response[:response])
            unless response.success?
              fail unsuccessful_response(response, message)
            end
          else
            fail 'Connection error'
          end
        end
        connections_present = verbose_response[:connections_present]
      end
      Setup::SystemNotification.create(type: :warning, message: "No connections processed") unless connections_present
      Setup::SystemNotification.create(type: :warning, message: "No records processed") unless records_processed
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
      file_extension = ((types = MIME::Types[http_response.content_type]).present? &&
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
      elsif (id = message[:source_id])
        [id]
      elsif scope_symbol == :filtered
        data_type.records_model.all.select { |record| field_triggers_apply_to?(:scope_filter, record) }.collect(&:id)
      elsif scope_symbol == :evaluation
        unless (parameters_size = scope_evaluator.parameters.size) == 1
          fail "Illegal arguments size for scope evaluator: #{parameters_size} (1 expected)"
        end
        if scope_evaluator.parameters.first.name == 'scope'
          evaluation = scope_evaluator.run(data_type.all)
          if evaluation.is_a?(Mongoid::Criteria) || evaluation.is_a?(Mongoff::Criteria)
            if evaluation.count == data_type.count
              nil
            else
              evaluation.distinct(:_id).flatten
            end
          elsif ((model = data_type.records_model).is_a?(Class) || evaluation.is_a?(Mongoff::Record)) &&
                evaluation.is_a?(model)
            [evaluation.id]
          elsif evaluation.is_a?(Array)
            evaluation.collect(&:id)
          else
            fail "Illegal scope evaluator result of type #{evaluation.class}: #{evaluation}"
          end
        else
          data_type.records_model.all.select { |record| scope_evaluator.run(record).present? }.collect(&:id)
        end
      else
        nil
      end
    end

  end
end
