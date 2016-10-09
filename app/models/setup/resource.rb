module Setup
  class Resource
    include CenitScoped
    include NamespaceNamed
    include JsonMetadata

    build_in_data_type.referenced_by(:namespace, :name)
    
    belongs_to :connection, class_name: Setup::Connection.to_s, inverse_of: :nil
    has_many :webhooks, class_name: Setup::Webhook.to_s, inverse_of: :nil
    
    field :path, type: String
    field :description, type: String
    
    validates_presence_of :path
  end
end
