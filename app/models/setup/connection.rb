module Setup
  class Connection
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include NumberGenerator

    has_many :webhooks, class_name: Setup::Webhook.name, inverse_of: :connection

    devise :database_authenticatable

    field :name, type: String
    field :url, type: String
    field :number, as: :key, type: String
    field :authentication_token, type: String

    before_save :ensure_authentication_token

    accepts_nested_attributes_for :webhooks

    validates_presence_of :name, :url
    validates_uniqueness_of :authentication_token

    def ensure_authentication_token
      self.authentication_token ||= generate_authentication_token
    end

    def generate_number(options = {})
      options[:prefix] ||= 'C'
      super(options)
    end

    rails_admin do      
      edit do
        field :name 
        field :url
        field :key
        field :authentication_token
        field :webhooks
      end
      list do
        field :name 
        field :url
        field :key
        field :authentication_token
        field :webhooks
      end
      show do
        field :_id
        field :created_at
        field :updated_at
        field :name 
        field :url
        field :key
        field :authentication_token
        field :webhooks
      end  
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
