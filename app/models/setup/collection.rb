module Setup
  class Collection
    include CenitScoped

    BuildInDataType.regist(self).embedding(:flows, :connection_roles, :translators, :events, :libraries, :webhooks, :connections).excluding(:image)

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
        {
          event: events,
          translator: translators,
          webhook: webhooks,
          connection_role: connection_roles,
          translator: translators
        }.each do |key, association|
          unless (value = flow.send(key)).nil? || association.detect { |v| v == value }
            association << value
          end
        end
        [:custom_data_type, :response_data_type].each do |key|
          unless (data_type = flow.send(key)).nil? || ((lib = data_type.schema.library) && libraries.detect { |v| v == lib })
            libraries << lib
          end
        end
      end
      connection_roles.each do |connection_role|
        connection_role.webhooks.each { |webhook| webhooks << webhook unless webhooks.detect { |v| v == webhook } }
        connection_role.connections.each { |connection| connections << connection unless connections.detect { |v| v == connection } }
      end
      translators.each do |translator|
        [:source_data_type, :target_data_type].each do |key|
          unless (data_type = translator.send(key)).nil? || ((lib = data_type.schema.library) && libraries.detect { |v| v == lib })
            libraries << lib
          end
        end
        [:source_exporter, :target_importer].each do |key|
          unless (t = translator.send(key)).nil? || translators.detect { |v| v == t }
            translators << t
          end
        end
      end
      events.each do |event|
        if event.is_a?(Setup::Observer) && (data_type = event.data_type) && !((lib = data_type.schema.library) && libraries.detect { |v| v == lib })
          libraries << lib
        end
      end
    end
  end
end
