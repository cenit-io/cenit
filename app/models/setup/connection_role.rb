module Setup
  class ConnectionRole
    include CenitScoped

    BuildInDataType.regist(self).referenced_by(:name)

    field :name, :type => String

    has_and_belongs_to_many :connections, class_name: Setup::Connection.to_s, inverse_of: :nil

    belongs_to :cenit_collection, class_name: Setup::Collection.to_s, inverse_of: :connection_roles
  end
end
