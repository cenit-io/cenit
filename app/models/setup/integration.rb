module Setup
  class Integration < ReqRejValidator
    include CenitScoped

    BuildInDataType.regist(self)

    field :name, type: String

    belongs_to :pull_connection, class_name: Setup::Connection.to_s, inverse_of: nil
    belongs_to :pull_flow, class_name: Setup::Flow.to_s, inverse_of: nil
    belongs_to :pull_event, class_name: Setup::Event.to_s, inverse_of: nil

    belongs_to :pull_translator, class_name: Setup::Translator.to_s, inverse_of: nil
    belongs_to :data_type, class_name: Setup::DataType.to_s, inverse_of: nil
    belongs_to :send_translator, class_name: Setup::Translator.to_s, inverse_of: nil

    belongs_to :send_flow, class_name: Setup::Flow.to_s, inverse_of: nil
    belongs_to :receiver_connection, class_name: Setup::Connection.to_s, inverse_of: nil

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
      unless requires(:pull_connection, :pull_event, :receiver_connection, :data_type)
        unless pull_flow.present?
          name = uniq_name("Pull #{data_type.custom_title} from #{pull_connection.name}", Setup::Flow)
          self.pull_flow = Setup::Flow.new(name: name, event: pull_event)
        end
        unless pull_flow.translator.present?
          name = uniq_name("Import #{data_type.custom_title} from #{pull_connection.name}", Setup::Translator)
          pull_flow.translator = Setup::Translator.create(name: name, type: :Import, target_data_type: data_type, style: :ruby, transformation: RUBY_IMPORT_TRANSFORMATION)
          pull_flow.translator.instance_variable_set(:@dynamically_created, true)
        end
        self.pull_translator = pull_flow.translator
        unless pull_flow.webhook.present?
          name = uniq_name("Get #{data_type.custom_title}", Setup::Webhook)
          pull_flow.webhook = Setup::Webhook.create(name: name, method: :get, path: data_type.name.underscore.downcase)
          pull_flow.webhook.instance_variable_set(:@dynamically_created, true)
        end
        pull_flow.connection_role = connection_role_for(pull_connection, pull_flow.webhook) unless pull_flow.connection_role.present?
        pull_flow.instance_variable_set(:@dynamically_created, pull_flow.new_record?) if pull_flow.instance_variable_get(:@dynamically_created).nil?
        pull_flow.save

        unless send_flow.present?
          name = uniq_name("Send #{data_type.custom_title} to #{receiver_connection.name}", Setup::Flow)
          self.send_flow = Setup::Flow.new(name: name, event: Setup::Observer.create(data_type: data_type, triggers: '{"created_at":{"0":{"o":"_not_null","v":["","",""]}}}'))
          send_flow.event.instance_variable_set(:@dynamically_created, true)
        end
        unless send_flow.translator.present?
          name = uniq_name("Export #{data_type.custom_title} to #{receiver_connection.name}", Setup::Translator)
          send_flow.translator = Setup::Translator.create(name: name, type: :Export, source_data_type: data_type, style: :ruby, bulk_source: true, mime_type: 'application/json', transformation: RUBY_EXPORT_TRANSFORMATION)
          send_flow.translator.instance_variable_set(:@dynamically_created, true)
        end
        self.send_translator = send_flow.translator
        send_flow.data_type_scope = 'Event source' if send_flow.event.is_a?(Setup::Observer) && send_flow.event.data_type == send_flow.translator.data_type
        unless send_flow.webhook.present?
          name = uniq_name("Send #{data_type.custom_title}", Setup::Webhook)
          send_flow.webhook = Setup::Webhook.create(name: name, method: :post, path: "send_#{data_type.name.underscore.downcase}")
          send_flow.webhook.instance_variable_set(:@dynamically_created, true)
        end
        send_flow.connection_role = connection_role_for(receiver_connection, send_flow.webhook) unless send_flow.connection_role.present?
        send_flow.instance_variable_set(:@dynamically_created, send_flow.new_record?) if send_flow.instance_variable_get(:@dynamically_created).nil?
        send_flow.save
      end
      errors.blank?
    end

    def run_after_initialized
      validates_configuration
    end

    RUBY_IMPORT_TRANSFORMATION = <<-EOF
if (parsed_data = JSON.parse(data)).is_a?(Array)
  parsed_data.each { |item| target_data_type.create_from_json!(item) }
else
  target_data_type.create_from_json!(parsed_data)
end
    EOF

    RUBY_EXPORT_TRANSFORMATION = <<-EOF
if (jsons = sources.collect { |source| source.to_json(pretty: true, ignore: :id) } ).length == 1
  jsons[0]
else
  \"[\#{jsons.join(', ')}]\"
end
    EOF

    protected

    def connection_role_for(connection, webhook)
      i = -1
      name = uniq_name("#{connection.name} through #{webhook.name}", Setup::ConnectionRole)
      connection_role = Setup::ConnectionRole.create(name: name)
      connection_role.instance_variable_set(:@dynamically_created, true)
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
