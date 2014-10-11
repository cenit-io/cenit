module Setup
  class Connection < Base
    field :name, type: String
    field :url, type: String
    field :endpoint_id, type: String
    field :endpoint_token, type: String

    has_and_belongs_to_many :webhooks, :class_name => 'Setup::Webhook'

    validates_presence_of :name, :url
    
    rails_admin do 
      field :name
      field :url
      field :endpoint_id
      field :endpoint_token
    end  

  end
end
