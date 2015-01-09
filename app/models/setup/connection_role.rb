module Setup
  class ConnectionRole
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Trackable
       
    has_and_belongs_to_many :connections, class_name: Setup::Connection.name
    has_and_belongs_to_many :webhooks, class_name: Setup::Webhook.name
    belongs_to :template, class_name: Setup::Template.name, inverse_of: :connection_roles 
  
    field :name, :type => String
  end
end
