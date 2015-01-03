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
    
    # Associated fields with request
    belongs_to :schema_validation, class_name: Setup::Schema.name
    belongs_to :data_type, class_name: Setup::DataType.name
    field :trigger_event, type: Boolean
    
    # Associated fields with response
    belongs_to :schema_validation_response, class_name: Setup::Schema.name
    belongs_to :data_type_response, class_name: Setup::DataType.name
    field :trigger_event_response, type: Boolean 
     
    has_and_belongs_to_many :connections, class_name: Setup::Connection.name
    has_and_belongs_to_many :connection_roles, class_name: Setup::ConnectionRole.name

    validates_presence_of :name, :path, :purpose
  end
end
