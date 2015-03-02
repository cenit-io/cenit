require 'nokogiri'

module Setup
  class Flow < ShortcutValidator
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Setup::Enum
    include Trackable
    include DynamicValidators

    BuildInDataType.regist(self)

    field :name, type: String
    field :active, type: Boolean, default: :true
    field :discard_events, type: Boolean

    belongs_to :event, class_name: Setup::Event.name, inverse_of: nil

    belongs_to :translator, class_name: Setup::Translator.name, inverse_of: nil
    belongs_to :custom_data_type, class_name: Setup::DataType.name, inverse_of: nil
    field :data_type_scope, type: String
    field :lot_size, type: Integer

    belongs_to :connection_role, class_name: Setup::ConnectionRole.name, inverse_of: nil
    belongs_to :webhook, class_name: Setup::Webhook.name, inverse_of: nil

    belongs_to :response_translator, class_name: Setup::Translator.name, inverse_of: nil
    belongs_to :response_data_type, class_name: Setup::DataType.name, inverse_of: nil

    field :last_trigger_timestamps, type: DateTime

    belongs_to :template, class_name: Setup::Template.name, inverse_of: :flows

    validates_presence_of :name, :event, :translator
    validates_numericality_in_presence_of :lot_size, greater_than_or_equal_to: 1
    before_save :validates_configuration

    def validates_configuration
      return false unless ready_to_save?
      unless requires(:event, :translator)
        if translator.data_type.nil?
          requires(:custom_data_type)
        else
          rejects(:custom_data_type)
        end
        if translator.type == :Import
          rejects(:data_type_scope)
        else
          requires(:data_type_scope)
        end
        if [:Import, :Export].include?(translator.type)
          requires(:connection_role, :webhook)
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
        else
          rejects(:lot_size, :response_translator, :response_data_type)
        end
      end
      errors.blank?
    end

    def reject_message(field=nil)
      case field
        when :custom_data_type
          'is not allowed since translator already defines a data type'
        when :data_type_scope
          'is not allowed for import translators'
        when :response_data_type
          if response_translator.present?
            'is not allowed since response translator already defines a data type'
          else
            "can't be defined until response translator"
          end
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
      event || translator
    end

    def process(options={})
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
        if object_ids = message[:object_ids]
          data_type.records_model.any_in(id: object_ids).each { |obj| translator.run(object: obj, discard_events: discard_events) }
        elsif scope_symbol == :all
          data_type.records_model.all.each { |obj| translator.run(object: obj, discard_events: discard_events) }
        elsif obj_id = message[:source_id]
          translator.run(object: data_type.records_model.find(obj_id), discard_events: discard_events)
        end
      rescue Exception => ex
        block.yield(exception: ex) if block
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
                                           'X_HUB_STORE' => connection.key,
                                           'X_HUB_TOKEN' => connection.token,
                                           'X_HUB_TIMESTAMP' => Time.now.utc.to_i.to_s
                                       }
                                   })
          translator.run(target_data_type: data_type,
                         data: response.message,
                         discard_events: discard_events) if response.code == 200
          block.yield(response: response) if block
        rescue Exception => ex
          block.yield(response: response, exception: ex) if block
        end
      end
    end

    def translate_export(message, &block)
      limit = lot_size || 1000
      max = ((object_ids = source_ids_from(message)) ? object_ids.size : data_type.count) - 1
      0.step(max, limit) do |offset|
        puts result = translator.run(object_ids: object_ids,
                                     source_data_type: data_type,
                                     offset: offset,
                                     limit: limit,
                                     discard_events: discard_events)
        connection_role.connections.each do |connection|
          begin
            result = check_root(data_type, result)
            response = HTTParty.send(webhook.method, connection.url + '/' + webhook.path,
                                     {
                                         body: result,
                                         headers: {
                                             'Content-Type' => 'application/json',
                                             'X_HUB_STORE' => connection.key,
                                             'X_HUB_TOKEN' => connection.token,
                                             'X_HUB_TIMESTAMP' => Time.now.utc.to_i.to_s
                                         }
                                     })
            block.yield(response: response) if block
            if response_translator #&& response.code == 200
              response_translator.run(target_data_type: response_translator.data_type || response_data_type, data: response.message)
            end
          rescue Exception => ex
            block.yield(exception: ex) if block
          end
        end
      end
    end

    def check_root(data_type, result)
      root_key = data_type.name.downcase
      result_hash = JSON.parse(result)
      unless result_hash.has_key? root_key
        result = {root_key => result_hash}.to_json
      end
      result
    end

    def source_ids_from(message)
      if object_ids = message[:object_ids]
        object_ids
      elsif scope_symbol == :event_source
        (id = message[:source_id]) ? [id] : []
      else
        nil
      end
    end

    def scope_symbol
      data_type_scope.start_with?('Event') ? :event_source : :all
    end
  end
end
