module Setup
  class Webhook
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include MakeSlug
    include Trackable

    include Setup::Enum

    field :id, :type => String
    field :name, type: String
    field :path, type: String
    field :purpose, type: String, default: :send
    field :method, type: String, default: :post
    
    def method_enum
      [:get,:post, :put, :delete, :copy, :head, :options, :link, :unlink, :purge, :lock, :unlock, :propfind]
    end
    
    has_and_belongs_to_many :templates, class_name: Setup::Template.name, inverse_of: :connection_roles
    
    # Associated fields with request
    belongs_to :schema_validation, class_name: Setup::Schema.name
    belongs_to :data_type, class_name: Setup::DataType.name
    field :trigger_event, type: Boolean
    
    # Associated fields with response
    belongs_to :schema_validation_response, class_name: Setup::Schema.name
    belongs_to :data_type_response, class_name: Setup::DataType.name
    field :trigger_event_response, type: Boolean 

    has_and_belongs_to_many :connection_roles, class_name: Setup::ConnectionRole.name
    
    has_many :url_parameters, class_name: Setup::UrlParameter.name, as: :parameterizable
    has_many :headers, class_name: Setup::Header.name, as: :parameterizable

    validates_presence_of :name, :path, :purpose
    
    accepts_nested_attributes_for :url_parameters, :headers
    
    def relative_url
      "/#{path}"
    end   
  end
end
