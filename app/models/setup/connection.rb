module Setup
  class Connection < Base
    field :name, type: String
    field :url, type: String
    field :key, type: String
    field :token, type: String

    has_many :connection_webhooks, class_name: 'Setup::ConnectionWebhook', inverse_of: :connection
    
    accepts_nested_attributes_for :connection_webhooks

    validates_presence_of :name, :url
    
    rails_admin do 
      field :name
      field :url
      field :key
      field :token
      field :connection_webhooks
    end  

  end
end
