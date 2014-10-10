module Setup
  class Connection < Base
    field :name, type: String
    field :url, type: String
    field :store, type: String
    field :token, type: String

    has_and_belongs_to_many :webhooks, :class_name => 'Setup::Webhook'

    validates_presence_of :name, :url
    
    rails_admin do 
      field :name
      field :url
      field :store
      field :token
    end  

  end
end
