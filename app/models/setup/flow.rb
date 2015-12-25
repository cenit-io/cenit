require 'nokogiri'

module Setup
  class Flow < ReqRejValidator
    include CenitScoped
    include NamespaceNamed
    include TriggersFormatter

    BuildInDataType.regist(self).referenced_by(:namespace, :name).excluding(:notify_response, :notify_request)

    field :active, type: Boolean, default: :true
    field :notify_request, type: Boolean, default: :false
    field :notify_response, type: Boolean, default: :false
    field :discard_events, type: Boolean

    belongs_to :event, class_name: Setup::Event.to_s, inverse_of: nil

    belongs_to :translator, class_name: Setup::Translator.to_s, inverse_of: nil
    belongs_to :custom_data_type, class_name: Setup::DataType.to_s, inverse_of: nil
    field :nil_data_type, type: Boolean
    field :data_type_scope, type: String
    field :scope_filter, type: String
    belongs_to :scope_evaluator, class_name: Setup::Algorithm.to_s, inverse_of: nil
    field :lot_size, type: Integer

    belongs_to :webhook, class_name: Setup::Webhook.to_s, inverse_of: nil
    belongs_to :connection_role, class_name: Setup::ConnectionRole.to_s, inverse_of: nil

    belongs_to :response_translator, class_name: Setup::Translator.to_s, inverse_of: nil
    belongs_to :response_data_type, class_name: Setup::DataType.to_s, inverse_of: nil

    has_and_belongs_to_many :after_process_callbacks, class_name: Setup::Algorithm.to_s, inverse_of: nil

    field :last_trigger_timestamps, type: Time

    validates_numericality_in_presence_of :lot_size, greater_than_or_equal_to: 1
    before_save :validates_configuration, :check_scheduler
    after_save :schedule_task

    def validates_configuration
      format_triggers_on(:scope_filter) if scope_filter.present?
      return false unless ready_to_save?
      unless requires(:name, :translator)
        if translator.data_type.nil?
          requires(:custom_data_type) unless translator.type == :Export && nil_data_type
        else
          rejects(:custom_data_type)
        end
        if translator.type == :Import
          rejects(:data_type_scope, :scope_filter, :scope_evaluator)
        else
          requires(:data_type_scope) unless translator.type == :Export && data_type.nil?
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
        else
          rejects(:connection_role, :webhook, :notify_request, :notify_response)
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
          rejects(:custom_data_type, :data_type_scope, :lot_size) if nil_data_type
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

    def data_type
      (translator && translator.data_type) || custom_data_type
    end

    def data_type_scope_enum
      enum = []
      if data_type
        enum << 'Event source' if event && event.try(:data_type) == data_type
        enum << "All #{data_type.title.downcase.pluralize}"
        enum << 'Filter'
        enum << 'Evaluator'
      end
      enum
    end

    def ready_to_save?
      translator.present? && (translator.type == :Import || data_type_scope.present? || (translator.type == :Export && nil_data_type && webhook.present?))
    end

    def can_be_restarted?
      event || translator
    end

    def process(message={})
      puts "Flow processing on '#{self.name}': #{}"
      executing_id, execution_graph = (Thread.current[:flow_execution] ||= []).last || [nil, {}]
      if executing_id.present? && !(adjacency_list = execution_graph[executing_id] ||= []).include?(id.to_s)
        adjacency_list << id.to_s
      end
      result =
        if cycle = cyclic_execution(execution_graph, executing_id)
          cycle = cycle.collect { |id| ((flow = Setup::Flow.where(id: id).first) && flow.name) || id }
          Setup::Notification.create(message: "Cyclic flow execution: #{cycle.join(' -> ')}")
        else
          Setup::FlowExecution.process message.merge(flow_id: id.to_s,
                                                     tirgger_flow_id: executing_id,
                                                     execution_graph: execution_graph)
        end
      puts "Flow processing jon '#{self.name}' done!"
      self.last_trigger_timestamps = DateTime.now
      save
      result
    end

    def translate(message, &block)
      if translator.present?
        begin
          (flow_execution = Thread.current[:flow_execution] ||= []) << [id.to_s, message[:execution_graph] || {}]
          send("translate_#{translator.type.to_s.downcase}", message, &block)
          after_process_callbacks.each do |callback|
            begin
              callback.run(message[:task])
            rescue Exception => ex
              Setup::Notification.create(message: "Error executing after process callback #{callback.custom_title}: #{ex.message}")
            end
          end
        ensure
          flow_execution.pop
        end
      else
        yield(message: "Flow translator can't be blank")
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

    def cyclic_execution(execution_graph, start_id, cycle=[])
      if cycle.include?(start_id)
        cycle << start_id
        return cycle
      elsif adjacency_list = execution_graph[start_id]
        cycle << start_id
        adjacency_list.each { |id| return cycle if cyclic_execution(execution_graph, id, cycle) }
        cycle.pop
      end
      false
    end

    def simple_translate(message, &block)
      object_ids = ((obj_id = message[:source_id]) && [obj_id]) || source_ids_from(message)
      if translator.source_handler
        begin
          translator.run(object_ids: object_ids, discard_events: discard_events, task: message[:task])
        rescue Exception => ex
          fail "Error source handling translation of records of type '#{data_type.custom_title}' with '#{translator.custom_title}': #{ex.message}"
        end
      else
        if object_ids
          data_type.records_model.any_in(id: object_ids)
        else
          data_type.records_model.all
        end.each do |obj|
          begin
            translator.run(object: obj, discard_events: discard_events, task: message[:task])
          rescue Exception => ex
            fail "Error translating record with ID '#{obj.id}' of type '#{data_type.custom_title}' when executing '#{translator.custom_title}': #{ex.message}"
          end
        end
      end
    rescue Exception => ex
      block.yield(message: ex.message) if block
    end

    def translate_conversion(message, &block)
      simple_translate(message, &block)
    end

    def translate_update(message, &block)
      simple_translate(message, &block)
    end

    def translate_import(message, &block)
      webhook.upon(connection_role).submit(notify_request: notify_request,
                                           notify_response: notify_response) do |response, template_parameters|
        translator.run(target_data_type: data_type,
                       data: response.body,
                       discard_events: discard_events,
                       parameters: template_parameters,
                       headers: response.headers,
                       task: message[:task]) if response.code == 200
      end
    end

    def translate_export(message, &block)
      limit = translator.bulk_source ? lot_size || 1000 : 1
      max = ((object_ids = source_ids_from(message)) ? object_ids.size : data_type.count) - (scope_symbol ? 1 : 0)
      translation_options = nil
      connections_present = true
      0.step(max, limit) do |offset|
        next unless connections_present
        verbose_response =
          webhook.upon(connection_role).submit ->(template_parameters) {
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
              response_translator.run(translation_options.merge(target_data_type: response_translator.data_type || response_data_type, data: response.body))
            end
            true
          end
        connections_present = verbose_response[:connections_present]
      end
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
      if object_ids = message[:object_ids]
        object_ids
      elsif scope_symbol.nil?
        []
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
  end
end
