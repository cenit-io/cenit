require 'nokogiri'

module Setup
  class Flow
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Setup::Enum
    include Trackable
    include DynamicValidators

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

    #has_and_belongs_to_many :templates, class_name: Setup::Template.name, inverse_of: :flows

    field :last_trigger_timestamps, type: DateTime

    validates_presence_of :name, :event, :translator
    validates_numericality_in_presence_of :lot_size, greater_than_or_equal_to: 1
    before_save :validates_configuration

    def validates_configuration
      errors.add(:event, "can't be blank") unless event
      if translator
        if translator.data_type.nil?
          errors.add(:custom_data_type, "can't be blank") unless custom_data_type
        else
          errors.add(:custom_data_type, 'is not allowed since translator already defines a data type') if custom_data_type
        end
        if translator.type == :Import
          errors.add(:data_type_scope, 'is not allowed for import translators') if data_type_scope
        else
          errors.add(:data_type_scope, "can't be blank") unless data_type_scope
        end
        [:connection_role, :webhook].each do |field|
          if send(field)
            errors.add(field, 'is not allowed') unless [:Import, :Export].include?(translator.type)
          else
            errors.add(field, "can't be blank") if [:Import, :Export].include?(translator.type)
          end
        end
        if translator.type == :Export
          if response_translator.present?
            if response_translator.data_type
              errors.add(:response_data_type, 'is not allowed since response translator already defines a data type')
            else
              errors.add(:response_data_type, "is needed for response translator #{response_translator.name}") unless response_data_type.present?
            end
          else
            [:response_data_type, :discard_events].each do |field|
              errors.add(field, "can't be defined until response translator") if send(field)
            end
          end
        else
          [:lot_size, :response_translator, :response_data_type, :discard_events].each do |field|
            errors.add(field, 'is not allowed for non export translators') if send(field)
          end
        end
      else
        errors.add(:translator, "can't be blank")
      end
      errors.blank?
    end

    def data_type
      (translator && translator.data_type) || custom_data_type
    end

    def data_type_scope_enum
      enum = []
      if data_type
        enum << "Event source" if event && event.data_type == data_type
        enum << "All #{data_type.title.downcase.pluralize}"
      end
      enum
    end

    def ready_to_save?
      event && translator && (translator.type == :Import || data_type_scope.present?)
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
        if scope_symbol == :all
          data_type.model.all.each { |obj| translator.run(object: obj) }
        elsif obj_id = message[:source_id]
          translator.run(object: data_type.model.find(obj_id), discard_events: discard_events)
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
      max = ((object_ids = source_ids_from(message)) ? object_ids.size : data_type.model.count) - 1
      0.step(max, limit) do |offset|
        result = translator.run(object_ids: object_ids,
                                source_data_type: data_type,
                                offset: offset,
                                limit: limit,
                                discard_events: discard_events)
        connection_role.connections.each do |connection|
          begin
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

    def source_ids_from(message)
      if scope_symbol == :event_source
        (id = message[:source_id]) ? [id] : []
      else
        nil
      end
    end

    def scope_symbol
      data_type_scope.start_with?('Event') ? :event_source : :all
    end

    rails_admin do
      edit do
        field :name
        field :event do
          inline_edit false
          inline_add false
          associated_collection_scope do
            event = bindings[:object].event
            Proc.new { |scope|
              event ? scope.where(id: event.id) : scope.all
            }
          end
        end
        field :translator do
          inline_edit false
          inline_add false
          associated_collection_scope do
            translator = bindings[:object].translator
            Proc.new { |scope|
              translator ? scope.where(id: translator.id) : scope.all
            }
          end
        end
        field :custom_data_type do
          inline_edit false
          inline_add false
          visible do
            if (f = bindings[:object]).event && f.translator && f.translator.data_type.nil?
              f.instance_variable_set(:@selecting_data_type, f.custom_data_type = f.event && f.event.data_type) unless f.data_type
              true
            else
              false
            end
          end
          label do
            if (translator = bindings[:object].translator)
              if [:Export, :Conversion].include?(translator.type)
                'Source data type'
              else
                'Target data type'
              end
            else
              'Data type'
            end
          end
          help 'Required'
          associated_collection_scope do
            data_type = bindings[:object].instance_variable_get(:@selecting_data_type) ? nil : bindings[:object].data_type
            Proc.new { |scope|
              data_type ? scope.where(id: data_type.id) : scope.all
            }
          end
        end
        field :data_type_scope do
          visible { (f = bindings[:object]).event && f.translator && f.translator.type != :Import && f.data_type && !f.instance_variable_get(:@selecting_data_type) }
          label do
            if (translator = bindings[:object].translator)
              if [:Export, :Conversion].include?(translator.type)
                'Source scope'
              else
                'Target scope'
              end
            else
              'Data type scope'
            end
          end
          help 'Required'
        end
        field :lot_size do
          visible { (f = bindings[:object]).event && f.translator && f.translator.type == :Export && f.data_type_scope && f.scope_symbol != :event_source }
        end
        field :connection_role do
          visible { (translator = bindings[:object].translator) && (translator.type == :Import || (translator.type == :Export && bindings[:object].data_type_scope.present?)) }
          help 'Required'
        end
        field :webhook do
          visible { (translator = bindings[:object].translator) && (translator.type == :Import || (translator.type == :Export && bindings[:object].data_type_scope.present?)) }
          help 'Required'
        end
        field :response_translator do
          inline_edit false
          inline_add false
          visible { (translator = bindings[:object].translator) && translator.type == :Export && bindings[:object].ready_to_save? }
          associated_collection_scope do
            Proc.new { |scope|
              scope.where(type: :Import)
            }
          end
        end
        field :response_data_type do
          inline_edit false
          inline_add false
          visible { (response_translator = bindings[:object].response_translator) && response_translator.data_type.nil? }
          help ''
        end
        field :active do
          visible { bindings[:object].ready_to_save? }
        end
        field :discard_events do
          visible { bindings[:object].ready_to_save? }
        end
      end

      show do
        field :name
        field :event
        field :translator

        field :_id
        field :created_at
        field :creator
        field :updated_at
        field :updater
      end

      fields :name, :event, :translator
    end

  end
end
