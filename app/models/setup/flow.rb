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
    belongs_to :custom_data_type, class_name: Setup::DataType.to_s, inverse_of: nil
    field :data_type_scope, type: String
    field :lot_size, type: Integer

    belongs_to :connection_role, class_name: Setup::ConnectionRole.to_s, inverse_of: nil
    belongs_to :webhook, class_name: Setup::Webhook.to_s, inverse_of: nil

    belongs_to :response_translator, class_name: Setup::Translator.to_s, inverse_of: nil
    belongs_to :response_data_type, class_name: Setup::DataType.to_s, inverse_of: nil

    field :last_trigger_timestamps, type: DateTime

    belongs_to :cenit_collection, class_name: Setup::Collection.to_s, inverse_of: :flows

    validates_presence_of :name, :event, :translator
    validates_numericality_in_presence_of :lot_size, greater_than_or_equal_to: 1
    before_save :validates_configuration

    def validates_configuration
      return false unless ready_to_save?
      unless requires(:event, :translator)
        translator.data_type.nil? ? requires(:custom_data_type) : rejects(:custom_data_type)
        translator.type == :Import ? rejects(:data_type_scope) : requires(:data_type_scope)
        [:Import, :Export].include?(translator.type) ? requires(:webhook) : rejects(:connection_role, :webhook)

        if translator.type == :Export
          if response_translator.present?
            if response_translator.type == :Import
              response_translator.data_type.present? ? rejects(:response_data_type) : requires(:response_data_type)
            else
              errors.add(:response_translator, 'is not an import translator')
            end
          else
            rejects(:response_data_type, :discard_events)
          end
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
      end
      enum
    end

    def ready_to_save?
      (event && translator).present? && (translator.type == :Import || data_type_scope.present?)
    end

    def can_be_restarted?
      event.presence || translator
    end

    def process(options = {})
      puts "Flow processing on '#{self.name}': #{}"
      message = options.merge(flow_id: self.id.to_s, account_id: self.account.id.to_s).to_json
      begin
        Cenit::Rabbit.send_to_endpoints(message)
      rescue Exception => ex
        puts "ERROR sending message: #{ex.message}"
      end
      puts "Flow processing jon '#{self.name}' done!"
      self.last_trigger_timestamps = DateTime.now
      save
    end

    def translate(message, &block)
      send("translate_#{translator.type.to_s.downcase}", message, &block)
    end

    def simple_translate(message, &block)
      begin
        if (object_ids = message[:object_ids]).present?
          data_type.records_model.any_in(id: object_ids).each { |obj| translator.run(object: obj, discard_events: discard_events) }
        elsif scope_symbol == :all
          data_type.records_model.all.each { |obj| translator.run(object: obj, discard_events: discard_events) }
        elsif (obj_id = message[:source_id]).present?
          translator.run(object: data_type.records_model.find(obj_id), discard_events: discard_events)
        end
      rescue Exception => ex
        block.yield(exception: ex) if block.present?
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
          response = HTTParty.send(webhook.method, connection.url + '/' + webhook.path,
                                   {
                                       headers: {
                                           'X_HUB_TIMESTAMP' => Time.now.utc.to_i.to_s
                                       }
                                   })
          translator.run(
              target_data_type: data_type,
              data: response.message,
              discard_events: discard_events) if response.code == 200

          block.yield(response: response) if block.present?
        rescue Exception => ex
          block.yield(response: response, exception: ex) if block.present?
        end
      end
    end

    def translate_export(message, &block)
      limit = lot_size || 1000
      max = ((object_ids = source_ids_from(message)) ? object_ids.size : data_type.count) - 1
      0.step(max, limit) do |offset|
        puts result = translator.run(
            object_ids: object_ids,
            source_data_type: data_type,
            offset: offset,
            limit: limit,
            discard_events: discard_events)

        the_connections.each do |connection|
          begin
            if translator.mime_type == 'application/json' && (connection.parameters.present?|| webhook.parameters.present?)
              result = JSON.parse(result) unless result.is_a?(Hash)
              #TODO Check translation result already containing a key parameters
              parameters = result['parameters'] = {}
              connection.parameters.each { |p| parameters[p.key] = p.value }
              webhook.parameters.each { |p| parameters[p.key] = p.value }
            end
            headers = {
                'Content-Type' => translator.mime_type
            }
            connection.headers.each { |h| headers[h.key] = h.value }
            webhook.headers.each { |h| headers[h.key] = h.value }
            response = HTTParty.send(webhook.method, connection.url + '/' + webhook.path,
                                     {
                                         body: result,
                                         headers: headers
                                     })

            block.yield(response: response) if block.present?
            if response_translator #&& response.code == 200
              response_translator.run(target_data_type: response_translator.data_type || response_data_type, data: response.message)
            end
          rescue Exception => ex
            block.yield(exception: ex) if block.present?
          end
        end
      end
    end

    def source_ids_from(message)
      if (object_ids = message[:object_ids]).present?
        object_ids
      elsif scope_symbol == :event_source
        (id = message[:source_id]).present? ? [id] : []
      else
        nil
      end
    end

    def scope_symbol
      data_type_scope.start_with?('Event') ? :event_source : :all
    end

    def the_connections
      if connection_role.present?
        connection_role.connections
      else
        webhook.connections
      end
    end
  end
end
