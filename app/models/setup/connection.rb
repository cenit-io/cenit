module Setup
  class Connection
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include NumberGenerator
    include Trackable
    
    has_and_belongs_to_many :connection_roles, class_name: Setup::ConnectionRole.name, inverse_of: :connections
    has_many :url_parameters, class_name: Setup::UrlParameter.name, as: :parameterizable
    has_many :headers, class_name: Setup::Header.name, as: :parameterizable
    
    devise :database_authenticatable

    field :id, :type => String
    field :name, type: String
    field :url, type: String
    field :number, as: :key, type: String
    field :token, type: String

    after_initialize :ensure_token

    accepts_nested_attributes_for :url_parameters, :headers, :connection_roles

    validates_presence_of :name, :url, :key, :token
    validates_uniqueness_of :token

    def ensure_token
      self.token ||= generate_token
    end

    def generate_number(options = {})
      options[:prefix] ||= 'C'
      super(options)
    end

    private

      def generate_token
        loop do
          token = Devise.friendly_token
          break token unless Setup::Connection.where(token: token).first
        end
      end

  end
end
