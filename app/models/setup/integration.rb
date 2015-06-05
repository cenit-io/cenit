module Setup
  class Integration < ReqRejValidator
    include CenitScoped

    BuildInDataType.regist(self)

    field :name, type: String

    belongs_to :pull_connection, class_name: Setup::Connection.to_s, inverse_of: nil
    belongs_to :pull_flow, class_name: Setup::Flow.to_s, inverse_of: nil
    belongs_to :pull_event, class_name: Setup::Event.to_s, inverse_of: nil

    belongs_to :pull_translator, class_name: Setup::Translator.to_s, inverse_of: nil
    belongs_to :data_type, class_name: Setup::Model.to_s, inverse_of: nil
    belongs_to :send_translator, class_name: Setup::Translator.to_s, inverse_of: nil

    belongs_to :send_flow, class_name: Setup::Flow.to_s, inverse_of: nil
    belongs_to :receiver_connection, class_name: Setup::Connection.to_s, inverse_of: nil

    validates_presence_of :pull_connection, :pull_event, :receiver_connection, :data_type

    before_save :check_new_record, :validates_configuration

    def check_new_record
      if new_record?
        true
      else
        errors.add(:base, "Can't be updated (create a new one)")
        false
      end
    end

    def validates_configuration
      unless pull_flow.present?
        name = uniq_name("Pull #{data_type.on_library_title} from #{pull_connection.name}", Setup::Flow)
        self.pull_flow = Setup::Flow.new(name: name, event: pull_event)
      end
      unless pull_flow.translator.present?
        name = uniq_name("Import #{data_type.on_library_title} from #{pull_connection.name}", Setup::Translator)
        pull_flow.translator = Setup::Translator.create(name: name, type: :Import, target_data_type: data_type, style: :ruby, transformation: RUBY_IMPORT_TRANSFORMATION)
        pull_flow.translator.instance_variable_set(:@dynamically_saved, true)
      end
      unless pull_flow.webhook.present?
        name = uniq_name("Get #{data_type.on_library_title}", Setup::Webhook)
        pull_flow.webhook = Setup::Webhook.create(name: name, purpose: :receive, method: :get, path: data_type.name.underscore.downcase)
        pull_flow.webhook.instance_variable_set(:@dynamically_saved, true)
      end
      pull_flow.connection_role = connection_role_for(pull_connection, pull_flow.webhook) unless pull_flow.connection_role.present?
      pull_flow.instance_variable_set(:@dynamically_saved, pull_flow.new_record?) if pull_flow.instance_variable_get(:@dynamically_saved).nil?
      pull_flow.save

      unless send_flow.present?
        name = uniq_name("Send #{data_type.on_library_title} to #{receiver_connection.name}", Setup::Flow)
        self.send_flow = Setup::Flow.new(name: name, event: Setup::Observer.create(data_type: data_type, triggers: '{"created_at":{"0":{"o":"_not_null","v":["","",""]}}}'))
        send_flow.event.instance_variable_set(:@dynamically_saved, true)
      end
      unless send_flow.translator.present?
        name = uniq_name("Export #{data_type.on_library_title} to #{receiver_connection.name}", Setup::Translator)
        send_flow.translator = Setup::Translator.create(name: name, type: :Export, source_data_type: data_type, style: :ruby, bulk_source: true, mime_type: 'application/json', transformation: RUBY_EXPORT_TRANSFORMATION)
        send_flow.translator.instance_variable_set(:@dynamically_saved, true)
      end
      send_flow.data_type_scope = 'Event source' if send_flow.event.is_a?(Setup::Observer) && send_flow.event.data_type == send_flow.translator.data_type
      unless send_flow.webhook.present?
        name = uniq_name("Send #{data_type.on_library_title}", Setup::Webhook)
        send_flow.webhook = Setup::Webhook.create(name: name, purpose: :send, method: :post, path: "send_#{data_type.name.underscore.downcase}")
        send_flow.webhook.instance_variable_set(:@dynamically_saved, true)
      end
      send_flow.connection_role = connection_role_for(receiver_connection, send_flow.webhook) unless send_flow.connection_role.present?
      send_flow.instance_variable_set(:@dynamically_saved, send_flow.new_record?) if send_flow.instance_variable_get(:@dynamically_saved).nil?
      send_flow.save

      errors.blank?
    end

    def run_after_initialized
      validates_configuration
    end

    RUBY_IMPORT_TRANSFORMATION =
      'if (parsed_data = JSON.parse(data)).is_a?(Array)
  parsed_data.each { |item| target_data_type.create_from_json!(item) }
else
  target_data_type.create_from_json!(parsed_data)
end'

    RUBY_EXPORT_TRANSFORMATION =
      "if (jsons = sources.collect { |source| source.to_json(pretty: true, ignore: :id) } ).length == 1
    jsons[0]
else
  \"[\#{jsons.join(', ')}]\"
end"

    rails_admin do
      edit do
        field :name
        field :pull_connection
        field :pull_event do
          inline_add { false }
          inline_edit { false }
        end
        field :data_type
        field :receiver_connection
      end
      show do
        field :name
        field :pull_connection
        field :pull_flow
        field :pull_event
        field :pull_translator
        field :data_type
        field :send_translator
        field :send_flow
        field :receiver_connection
      end
    end

    protected

    def connection_role_for(connection, webhook)
      i = -1
      name = uniq_name("#{connection.name} through #{webhook.name}", Setup::ConnectionRole)
      connection_role = Setup::ConnectionRole.create(name: name)
      connection_role.instance_variable_set(:@dynamically_saved, true)
      connection_role.connections << connection
      connection_role.webhooks << webhook
      connection_role
    end


    def uniq_name(base_name, model)
      i = 1
      while model.where(name: base_name).present?
        base_name = base_name.gsub(/ \(\d*\)\Z/, '') + " (#{i += 1})"
      end
      base_name
    end
  end
end
