module Setup
  class Connection
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include NumberGenerator
    include Trackable
    
    has_and_belongs_to_many :connection_roles, class_name: Setup::ConnectionRole.name, inverse_of: :connections
    has_and_belongs_to_many :webhooks, class_name: Setup::Webhook.name, inverse_of: :connection
    has_many :url_parameters, class_name: Setup::UrlParameter.name, inverse_of: :connection
    has_many :headers, class_name: Setup::Header.name, inverse_of: :connection
    
    devise :database_authenticatable

    field :id, :type => String
    field :name, type: String
    field :url, type: String
    field :number, as: :key, type: String
    field :authentication_token, type: String

    after_initialize :ensure_authentication_token

    accepts_nested_attributes_for :url_parameters, :headers

    validates_presence_of :name, :url, :authentication_token, :key
    validates_uniqueness_of :authentication_token

    def ensure_authentication_token
      self.authentication_token ||= generate_authentication_token
    end

    def generate_number(options = {})
      options[:prefix] ||= 'C'
      super(options)
    end
    
    def get_webhokks
      webhooks.map{|w| w } + connection_roles.map {|cr| cr.webhooks.map{|w| w }.flatten }
    end  

    private

      def generate_authentication_token
        loop do
          token = Devise.friendly_token
          break token unless Setup::Connection.where(authentication_token: token).first
        end
      end

  end
end
