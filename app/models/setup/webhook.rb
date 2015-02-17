module Setup
  class Webhook
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Trackable
    include Setup::Enum
    
    has_many :url_parameters, class_name: Setup::UrlParameter.name, dependent: :destroy, as: :parameterizable
    has_many :headers, class_name: Setup::Header.name, dependent: :destroy, as: :parameterizable
    
    has_many :flows, class_name: Setup::Flow.name, dependent: :destroy, inverse_of: :webhook
    has_and_belongs_to_many :templates, class_name: Setup::Template.name, inverse_of: :webhooks
    has_and_belongs_to_many :connection_roles, class_name: Setup::ConnectionRole.name, inverse_of: :webhooks

    field :name, type: String
    field :path, type: String
    field :purpose, type: String, default: :send
    field :method, type: String, default: :post
    
    def method_enum
      [:get,:post, :put, :delete, :copy, :head, :options, :link, :unlink, :purge, :lock, :unlock, :propfind]
    end

    validates_presence_of :name, :path, :purpose
    
    accepts_nested_attributes_for :url_parameters, :headers
    
    def relative_url
      "/#{path}"
    end   
  end
end
