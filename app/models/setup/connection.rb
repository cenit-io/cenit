module Setup
  class Connection < Base
    field :name, type: String
    field :url, type: String
    field :key, type: String
    field :authentication_token, type: String
    
    devise :database_authenticatable, :token_authenticatable

    has_many :webhooks, class_name: 'Setup::Webhook', inverse_of: :connection
    
    accepts_nested_attributes_for :webhooks

    validates_presence_of :name, :url
    validates_uniqueness_of :authentication_token
    
    before_save :ensure_authentication_token

    def ensure_authentication_token
      self.authentication_token ||= generate_authentication_token
    end
    
    rails_admin do 
      field :name
      field :url
      field :key
      field :authentication_token
      field :webhooks
    end

    private

    def generate_authentication_token
      loop do
        token = Devise.friendly_token
        break token unless User.where(authentication_token: token).first
      end
    end
    
 

  end
end
