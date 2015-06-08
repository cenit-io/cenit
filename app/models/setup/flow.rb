require 'nokogiri'

module Setup
  class Flow < ReqRejValidator
    include CenitScoped
    include DynamicValidators

    BuildInDataType.regist(self)

    field :name, type: String
    field :active, type: Boolean, default: :true
    field :discard_events, type: Boolean

    belongs_to :event, class_name: Setup::Event.to_s, inverse_of: nil

    belongs_to :translator, class_name: Setup::Translator.to_s, inverse_of: nil
    belongs_to :custom_data_type, class_name: Setup::Model.to_s, inverse_of: nil
    field :nil_data_type, type: Boolean
    field :data_type_scope, type: String
    field :lot_size, type: Integer

    belongs_to :webhook, class_name: Setup::Webhook.to_s, inverse_of: nil
    belongs_to :connection_role, class_name: Setup::ConnectionRole.to_s, inverse_of: nil

    belongs_to :response_translator, class_name: Setup::Translator.to_s, inverse_of: nil
    belongs_to :response_data_type, class_name: Setup::Model.to_s, inverse_of: nil

    field :last_trigger_timestamps, type: Time

    validates_uniqueness_of :name
    validates_presence_of :name, :translator
    validates_numericality_in_presence_of :lot_size, greater_than_or_equal_to: 1
    before_save :validates_configuration

    def validates_configuration
      return false unless ready_to_save?
      unless requires(:translator)
        if translator.data_type.nil?
          requires(:custom_data_type) unless translator.type == :Export && nil_data_type
        else
          rejects(:custom_data_type)
        end
        if translator.type == :Import
          rejects(:data_type_scope)
        else
          requires(:data_type_scope) unless translator.type == :Export && data_type.nil?
        end
        if [:Import, :Export].include?(translator.type)
          requires(:webhook)
        else
          rejects(:connection_role, :webhook)
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
        enum << ''
      end
      enum
    end

    def ready_to_save?
      translator.present? && (translator.type == :Import || data_type_scope.present? || (translator.type == :Export && nil_data_type && webhook.present?))
    end

    def can_be_restarted?
      event || translator
    end

    def process(options={})
      puts "Flow processing on '#{self.name}': #{}"
      executing_id, execution_graph = (Thread.current[:flow_execution] ||= []).last || [nil, {}]
      if executing_id.present? && !(adjacency_list = execution_graph[executing_id] ||= []).include?(id.to_s)
        adjacency_list << id.to_s
      end
      if cycle = cyclic_execution(execution_graph, executing_id)
        cycle = cycle.collect { |id| ((flow = Setup::Flow.where(id: id).first) && flow.name) || id }
        Setup::Notification.create(flow: self, exception_message: "Cyclic flow execution: #{cycle.join(' -> ')}")
      else
        message = options.merge(flow_id: id.to_s, tirgger_flow_id: executing_id, execution_graph: execution_graph).to_json
        Cenit::Rabbit.send_to_endpoints(message)
      end
      puts "Flow processing jon '#{self.name}' done!"
      self.last_trigger_timestamps = DateTime.now
      save
    end

    def translate(message, &block)
      (flow_execution = Thread.current[:flow_execution] ||= []) << [id.to_s, message[:execution_graph] || {}]
      send("translate_#{translator.type.to_s.downcase}", message, &block)
      flow_execution.pop
    end

    private

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
      begin
        if object_ids = message[:object_ids]
          data_type.records_model.any_in(id: object_ids).each { |obj| translator.run(object: obj, discard_events: discard_events) }
        elsif scope_symbol.nil?
          translator.run(object: nil, discard_events: discard_events)
        elsif scope_symbol == :all
          data_type.records_model.all.each { |obj| translator.run(object: obj, discard_events: discard_events) }
        elsif obj_id = message[:source_id]
          translator.run(object: data_type.records_model.where(id: obj_id).first, discard_events: discard_events)
        end
      rescue Exception => ex
        block.yield(exception_message: ex.message) if block
      end
    end

    def translate_conversion(message, &block)
      simple_translate(message, &block)
    end

    def translate_update(message, &block)
      simple_translate(message, &block)
    end

    def translate_import(message, &block)
      connection_role.connections.each do |connection|
        begin
          http_response = HTTParty.send(webhook.method, connection.url + '/' + webhook.path,
                                        {headers: {'X_HUB_TIMESTAMP' => Time.now.utc.to_i.to_s}})
          translator.run(target_data_type: data_type,
                         data: http_response.message,
                         discard_events: discard_events) if http_response.code == 200
          block.yield(response: http_response.to_json, exception_message: (200...299).include?(http_response.code) ? nil : 'Unsuccessful') if block
        rescue Exception => ex
          block.yield(response: http_response.to_json, exception_message: ex.message) if block
        end
      end
    end

    def translate_export(message, &block)
      limit = translator.bulk_source ? lot_size || 1000 : 1
      max = ((object_ids = source_ids_from(message)) ? object_ids.size : data_type.count) - (scope_symbol ? 1 : 0)
      parameters = webhook.template_parameters_hash
      0.step(max, limit) do |offset|
        common_result = nil
        the_connections.each do |connection|
          translation_options =
              {
                  object_ids: object_ids,
                  source_data_type: data_type,
                  offset: offset,
                  limit: limit,
                  discard_events: discard_events,
                  parameters: parameters
              }
          translation_result =
              if connection.template_parameters.present?
                translator.run(translation_options.merge(parameters: connection.template_parameters_hash.merge(parameters)))
              else
                common_result ||= translator.run(translation_options)
              end
          headers = {'Content-Type' => translator.mime_type}.merge(connection.conformed_headers)
          webhook.headers.each { |h| headers[h.key] = h.value }
          begin
            http_response = HTTParty.send(webhook.method, connection.conformed_url + '/' + webhook.path,
                                          {
                                              body: translation_result,
                                              headers: headers
                                          })
            block.yield(response: http_response.to_json, exception_message: (200...299).include?(http_response.code) ? nil : 'Unsuccessful') if block.present?
            if response_translator #&& http_response.code == 200
              response_translator.run(target_data_type: response_translator.data_type || response_data_type, data: http_response.body)
            end
          rescue Exception => ex
            block.yield(exception_message: ex.message) if block
          end
        end
      end
    end

    def source_ids_from(message)
      if object_ids = message[:object_ids]
        object_ids
      elsif scope_symbol.nil?
        []
      elsif scope_symbol == :event_source && id = message[:source_id]
        [id]
      else
        nil
      end
    end

    def scope_symbol
      if data_type_scope.present?
        data_type_scope.start_with?('Event') ? :event_source : :all
      else
        nil
      end
    end

    def the_connections
      if connection_role.present?
        connection_role.connections
      else
        connections = []
        Setup::ConnectionRole.all.each do |connection_role|
          if connection_role.webhooks.include?(webhook)
            connections = (connections + connection_role.connections.to_a).uniq
          end
        end
        connections
      end
    end
  end
end
