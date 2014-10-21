module Setup
  class Connection < Base
    field :name, type: String
    field :url, type: String
    field :key, type: String
    field :token, type: String

    has_many :webhooks, class_name: 'Setup::Webhook', inverse_of: :connection
    
    accepts_nested_attributes_for :webhooks

    validates_presence_of :name, :url
    
    rails_admin do 
      field :name
      field :url
      field :key
      field :token
      field :webhooks
    end  

  end
end
