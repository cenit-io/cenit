module Setup
  class ConnectionRole
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Trackable

    BuildInDataType.regist(self).referenced_by(:name)

    field :name, :type => String

    has_and_belongs_to_many :connections, class_name: Setup::Connection.name, inverse_of: :nil

    belongs_to :template, class_name: Setup::Template.name, inverse_of: :connection_roles
  end
end
