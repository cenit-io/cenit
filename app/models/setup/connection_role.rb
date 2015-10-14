module Setup
  class ConnectionRole
    include CenitScoped

    BuildInDataType.regist(self).referenced_by(:name)

    field :name, :type => String

    has_and_belongs_to_many :webhooks, class_name: Setup::Webhook.to_s, inverse_of: :nil
    has_and_belongs_to_many :connections, class_name: Setup::Connection.to_s, inverse_of: :nil


    validates_uniqueness_of :name
  end
end
