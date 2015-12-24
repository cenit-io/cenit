module Setup
  class Parameter
    include CenitScoped
    include JsonMetadata

    BuildInDataType.regist(self).with(:key, :value, :description, :metadata)

    field :key, type: String
    field :value, type: String
    field :description, type: String

    embedded_in :connection, class_name: Setup::Connection.to_s
    embedded_in :webhook, class_name: Setup::Webhook.to_s

    validates_presence_of :key
    
    def to_s
      "#{key}: #{value}"
    end
  end 
end
