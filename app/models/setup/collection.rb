module Setup
  class Collection
    include CenitCommon

    BuildInDataType.regist(self).embedding(:translators, :events, :connection_roles, :webhooks)

    field :name, type: String

    has_many :libraries, class_name: Setup::Library.to_s, inverse_of: :cenit_collection
    has_many :translators, class_name: Setup::Translator.to_s, inverse_of: :cenit_collection
    has_many :events, class_name: Setup::Event.to_s, inverse_of: :cenit_collection
    has_many :connection_roles, class_name: Setup::ConnectionRole.to_s, inverse_of: :cenit_collection
    has_many :webhooks, class_name: Setup::Webhook.to_s, inverse_of: :cenit_collection
    has_many :flows, class_name: Setup::Flow.to_s, inverse_of: :cenit_collection
  end
end
