module Setup
  class Webhook
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Trackable

    include Setup::Enum

    field :name, type: String
    field :path, type: String
    field :purpose, type: String
    field :schema_validation, type: String

    belongs_to :data_type, class_name: Setup::DataType.name
    has_and_belongs_to_many :connection_roles, class_name: Setup::ConnectionRole.name, inverse_of: :webhooks

    validates_presence_of :name, :path, :purpose

  end
end
