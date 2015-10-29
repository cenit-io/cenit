module Setup
  class ConnectionRole
    include CenitScoped
    include NamespaceNamed

    BuildInDataType.regist(self).referenced_by(:namespace, :name)

    has_and_belongs_to_many :webhooks, class_name: Setup::Webhook.to_s, inverse_of: :nil
    has_and_belongs_to_many :connections, class_name: Setup::Connection.to_s, inverse_of: :nil

  end
end
