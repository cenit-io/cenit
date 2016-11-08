require 'nokogiri'

module Setup
  # A flow defines how data is processed by the execution of one or more actions.
  class Flow
    include ReqRejValidator
    include ShareWithBindings
    include NamespaceNamed
    include TriggersFormatter
    include ThreadAware
    include ModelConfigurable

    build_in_data_type.referenced_by(:namespace, :name)
    build_in_data_type.and(
      {
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
      }.deep_stringify_keys)

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
        validate_event
        validate_custom_data_type
        validate_scope
        validate_import_and_export
      end
      validate_callbacks
      errors.blank?
    end

    def reject_message(field = nil)
      case field
      when :custom_data_type
        I18n.t('flows.translator_already_defines_a_data_type')
      when :data_type_scope
        I18n.t('flows.not_allowed_import_translators')
      when :response_data_type
        if response_translator.present?
          I18n.t('flows.response_translator_already_defines_a_data_type')
        else
          I18n.t('flows.can_not_be_defined_until_response_translator')
        end
      when :discard_events
        I18n.t('flows.can_not_be_defined_until_response_translator')
      when :lot_size, :response_translator
        I18n.t('not_allowed_for_non_export_translators')
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
        fail I18n.t('data_type_option', data_type: data_type.custom_title, flow_data_type: flow_data_type)
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
        enum << "All #{data_type.title.downcase.pluralize}"
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
      return true if shared?
      cond = (t = translator).present?
      cond &&= event.blank? || data_type_scope.present? || t.type == :Import
      cond && ([:Export, :Import].exclude?(t.type) || webhook.present?)
    end

    def can_be_restarted?
      event || translator
    end

    def join_process(message = {})
      if (task_token = Thread.current[:task_token]) &&
         (thread_token = ThreadToken.where(token: task_token).first) &&
         (current_task = Task.where(thread_token: thread_token).first)
        process(message) { |task| task.join(current_task) }
      else
        process(message)
      end
    end

    def process(message = {}, &block)
      executing_id, execution_graph = current_thread_cache.last || [nil, {}]
      if executing_id.present? && !(adjacency_list = execution_graph[executing_id] ||= []).include?(id.to_s)
        adjacency_list << id.to_s
      end
      result = process_execution(message, execution_graph, executing_id)
      save!
      result
    end

    def translate(message, &block)
      return yield(message: I18n.t('flows.can_not_be_blank')) unless translator.present?
      begin
        (flow_execution = current_thread_cache) << [id.to_s, message[:execution_graph] || {}]
        data_type = Setup::BuildInDataType[message[:data_type_id]] ||
                    Setup::DataType.where(id: message[:data_type_id]).first
        using_data_type(data_type) if data_type
        send("translate_#{translator.type.to_s.downcase}", message, &block)
        after_process_callbacks.each do |callback|
          begin
            callback.run(message[:task])
          rescue StandardError => ex
            message = I18n.t('flows.error_after_callback', title: callback.custom_title, message: ex.message)
            Setup::Notification.create(message: message)
          end
        end
      ensure
        flow_execution.pop
      end
    end

    def scope_symbol
      return unless data_type_scope.nil?
      if data_type_scope.start_with?('Event')
        :event_source
      elsif data_type_scope.start_with?('Filter')
        :filtered
      elsif data_type_scope.start_with?('Eval')
        :evaluation
      else
        :all
      end
    end

    class << self
      def default_thread_value
        []
      end
    end

    private

    def process_execution(message, execution_graph, executing_id)
      if (cycle = cyclic_execution(execution_graph, executing_id))
        cycle = cycle.collect { |id| ((flow = Setup::Flow.where(id: id).first) && flow.name) || id }
        message = I18n.t('flows.cyclic', cycle: cycle.join(' -> '))
        Setup::Notification.create(message: message)
      else
        message = message.merge(
          flow_id: id.to_s,
          tirgger_flow_id: executing_id,
          execution_graph: execution_graph,
          auto_retry: auto_retry)
        Setup::FlowExecution.process(message, &block)
      end
    end

    def validate_event
      if event.present?
        unless translator.type == :Import || requires(:data_type_scope)
          if scope_symbol == :event_source &&
             !(event.is_a?(Setup::Observer) && event.data_type == data_type)
            errors.add(:event, I18n.t('flows.incompatible_data_type_scope'))
          end
        end
      elsif scope_symbol == :event_source
        persisted? ? requires(:event) : rejects(:data_type_scope)
      end
    end

    def validate_custom_data_type
      if translator.data_type.nil?
        requires(:custom_data_type) if translator.type == :Conversion && event.present?
      else
        rejects(:custom_data_type)
      end
    end

    def validate_scope
      return rejects(:data_type_scope, :scope_filter, :scope_evaluator) if translator.type == :Import
      case scope_symbol
      when :filtered
        format_triggers_on(:scope_filter, true)
        rejects(:scope_evaluator)
      when :evaluation
        unless requires(:scope_evaluator) || scope_evaluator.parameters.count == 1
          errors.add(:scope_evaluator, I18n.t('flows.must_receive_one_parameter'))
        end
        rejects(:scope_filter)
      else
        rejects(:scope_filter, :scope_evaluator)
      end
    end

    def validate_import_and_export
      if [:Import, :Export].include?(translator.type)
        requires(:webhook)
        validate_import
      else
        rejects(:before_submit, :connection_role, :authorization, :webhook, :notify_request, :notify_response)
      end
      validate_export
    end

    def validate_import
      if translator.type == :Import
        unless before_submit.nil? || before_submit.parameters.count == 1 || before_submit.parameters.count == 2
          errors.add(:before_submit,  I18n.t('flows.must_receive_one_or_two_parameters'))
        end
      else
        rejects(:before_submit)
      end
    end

    def validate_export
      return rejects(:lot_size, :response_translator, :response_data_type) unless translator.type == :Export
      rejects(:data_type_scope) if data_type.nil?
      return rejects(:response_data_type, :discard_events) unless response_translator.present?
      if response_translator.type == :Import
        response_translator.data_type ? rejects(:response_data_type) : requires(:response_data_type)
      else
        errors.add(:response, I18n.t('flows.not_an_import_translator'))
      end
    end

    def validate_callbacks
      bad_callbacks = after_process_callbacks.select { |c| c.parameters.count != 1 }
      if bad_callbacks.present?
        custom_titles = bad_callbacks.collect(&:custom_title).to_sentence
        message = I18n.t('flows.unexpected_parameter_size', title: custom_titles)
        errors.add(:after_process_callbacks, message)
      end
    end

    def check_scheduler
      @scheduler_checked =
        @scheduler_checked ? false : changed_attributes.key?(:event_id.to_s) && event.is_a?(Setup::Scheduler)
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
      if translator.source_handler
        begin
          translator.run(object_ids: object_ids, discard_events: discard_events, task: message[:task])
        rescue StandardError => ex
          raise I18n.t(
            'flows.error_handling_translation',
            data_type: data_type.custom_title,
            translator: translator.custom_title,
            message: ex.message)
        end
      else
        if object_ids
          data_type.records_model.any_in(id: object_ids)
        else
          data_type.records_model.all
        end.each do |obj|
          begin
            translator.run(object: obj, discard_events: discard_events, task: message[:task])
          rescue StandardError => ex
            raise I18n.t(
              'flows.error_translating_record',
              obj_id: obj.id,
              data_type: data_type.custom_title,
              translator: translator.custom_title,
              message: ex.message)
          end
        end
      end
    rescue StandardError => ex
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
          headers: {},
          parameters: {},
          template_parameters: {},
          notify_request: notify_request,
          notify_response: notify_response,
          verbose_response: true
        }
      if before_submit
        if before_submit.parameters.count == 1
          before_submit.run(options)
        elsif before_submit.parameters.count == 2
          before_submit.run([options, message[:task]])
        end
      end
      verbose_response =
        webhook.with(connection_role).and(authorization).submit(options) do |response, template_parameters|
          translator.run(
            target_data_type: data_type,
            data: response.body,
            discard_events: discard_events,
            parameters: template_parameters,
            headers: response.headers.to_hash,
            statusCode: response.code,
            task: message[:task]) # if response.code == 200
        end
      r_code = (200...299).exclude?(verbose_response[:http_response].code)
      if auto_retry == :automatic && r_code
        fail unsuccessful_response(verbose_response[:http_response], message)
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
        end
      max -= (scope_symbol ? 1 : 0)
      translation_options = nil
      connections_present = true
      0.step(max, limit) do |offset|
        next unless connections_present
        verbose_response =
          webhook.target.with(connection_role).and(authorization)
          .submit lambda(template_parameters) { run_translator(message, template_parameters, offset, limit) },
                  contentType: translator.mime_type,
                  notify_request: notify_request,
                  request_attachment: lambda(attachment) { request_attachment(attachment) },
                  notify_response: notify_response,
                  verbose_response: true do |response|
                    run_response(response, translation_options) if response # && response.code == 200
                    true
                  end
        if auto_retry == :automatic && (200...299).exclude?(verbose_response[:http_response].code)
          fail unsuccessful_response(verbose_response[:http_response], message)
        end
        connections_present = verbose_response[:connections_present]
      end
    end

    def run_translator(message, template_parameters, offset, limit)
      translation_options =
        { object_ids: object_ids,
          source_data_type: data_type,
          offset: offset,
          limit: limit,
          discard_events: discard_events,
          parameters: template_parameters,
          task: message[:task] }
      translator.run(translation_options)
    end

    def run_response(response_translator, translation_options)
      response_translator.run(
        translation_options.merge(
          target_data_type: response_translator.data_type || response_data_type,
          data: response.body,
          headers: response.headers.to_hash,
          statusCode: response.code, # TODO: Remove after deprecation migration
          response_code: response.code,
          requester_response: response.requester_response?))
    end

    def unsuccessful_response(http_response, task_msg)
      { error: I18n.t('unsuccessful_response_code'),
        code: http_response.code,
        user: ::User.current.label,
        user_id: ::User.current.id,
        tenant: Account.current.label,
        tenant_id: Account.current.id,
        task: task_msg,
        flow: to_hash,
        flow_attributes: attributes }.to_json
    end

    def attachment_from(http_response)
      return unless notify_response && http_response
      types = MIME::Types[http_response.content_type]
      file_extension = types.present? && ext_text(types.first.extensions.first) || ''
      { filename: http_response.object_id.to_s + file_extension,
        contentType: http_response.content_type,
        body: http_response.body }
    end

    def request_attachment(attachment)
      attachment[:filename] =
        ((data_type && data_type.title) || translator.name).collectionize +
        attachment[:filename] + ext_text(translator.file_extension)
      attachment
    end

    def ext_text(ext)
      ext.present? ? ".#{ext}" : ''
    end

    def source_ids_from(message)
      if (object_ids = message[:object_ids])
        object_ids
      elsif scope_symbol == :event_source && (id = message[:source_id])
        [id]
      elsif scope_symbol == :filtered
        data_type.records_model.all.select { |record| field_triggers_apply_to?(:scope_filter, record) }.collect(&:id)
      elsif scope_symbol == :evaluation
        data_type.records_model.all.select { |record| scope_evaluator.run(record).present? }.collect(&:id)
      end
    end
  end
end
