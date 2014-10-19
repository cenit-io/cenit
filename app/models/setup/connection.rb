module Setup
  class Connection < Base
    field :name, type: String
    field :url, type: String
    field :key, type: String
    field :token, type: String

    has_many :webhooks, class_name: 'Setup::Webhook', inverse_of: :connection
    has_many :flows, class_name: 'Setup::Flow', inverse_of: :connection
    
    accepts_nested_attributes_for :webhooks
    accepts_nested_attributes_for :flows

    validates_presence_of :name, :url
    
    rails_admin do 
      field :name
      field :url
      field :key
      field :token
      field :webhooks
      field :flows
    end  

  end
end
