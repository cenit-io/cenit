module Setup
  class Collection
    include CenitScoped

    BuildInDataType.regist(self).embedding(:translators, :connections, :webhooks, :connection_roles, :flows, :events)

    mount_uploader :image, CenitImageUploader
    field :name, type: String

    has_and_belongs_to_many :flows, class_name: Setup::Flow.to_s, inverse_of: nil
    has_and_belongs_to_many :connection_roles, class_name: Setup::ConnectionRole.to_s, inverse_of: nil

    has_and_belongs_to_many :translators, class_name: Setup::Translator.to_s, inverse_of: nil
    has_and_belongs_to_many :events, class_name: Setup::Event.to_s, inverse_of: nil
    has_and_belongs_to_many :libraries, class_name: Setup::Library.to_s, inverse_of: nil


    has_and_belongs_to_many :webhooks, class_name: Setup::Webhook.to_s, inverse_of: nil
    has_and_belongs_to_many :connections, class_name: Setup::Connection.to_s, inverse_of: nil


    before_save :check_dependencies

    def check_dependencies
      flows.each do |flow|
        events << flow.event if flow.event.present?
        translators << flow.translator if flow.translator.present?
        libraries << flow.custom_data_type.schema.library if flow.custom_data_type.present?
        webhooks << flow.webhook if flow.webhook.present?
        connection_roles << flow.connection_role if flow.connection_role.present?
        translators << flow.response_translator if flow.response_translator.present?
        libraries << flow.response_data_type.schema.library if flow.response_data_type.present?
      end
      connection_roles.each do |connection_role|
        connection_role.webhooks.each { |webhook| webhooks << webhook }
        connection_role.connections.each { |connection| connections << connection }
      end
      translators.each do |translator|
        libraries << translator.source_data_type.schema.library if translator.source_data_type.present?
        libraries << translator.target_data_type.schema.library if translator.target_data_type.present?
        translators << translator.source_exporter if translator.source_exporter.present?
        translators << translator.target_importer if translator.target_importer.present?
      end
      events.each do |event|
        libraries << event.data_type.schema.library if event.is_a?(Setup::Observer) && event.data_type.present?
      end

    end
  end
end
