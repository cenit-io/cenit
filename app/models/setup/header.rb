module Setup
  class Header
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped

    belongs_to :connection, class_name: Setup::Connection.name, inverse_of: :header
    belongs_to :webhook, class_name: Setup::Webhook.name, inverse_of: :header

    field :key, type: String
    field :value, type: String

    validates_presence_of :key, :value
     
  end
end
