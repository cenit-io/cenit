module Setup
  class Parameter
    include CenitCommon

    BuildInDataType.regist(self).with(:key, :value)

    field :key, type: String
    field :value, type: String

    embedded_in :connection, class_name: Setup::Connection.name
    embedded_in :webhook, class_name: Setup::Webhook.name

    validates_presence_of :key, :value
    
    def to_s
      "#{key}: #{value}"
    end
  end 
end
