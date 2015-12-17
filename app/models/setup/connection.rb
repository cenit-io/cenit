module Setup
  class Connection
    include CenitScoped
    include NamespaceNamed
    include NumberGenerator
    include ParametersCommon
    include AuthorizationHandler

    BuildInDataType.regist(self).referenced_by(:namespace, :name).excluding(:connection_roles)

    embeds_many :parameters, class_name: Setup::Parameter.to_s, inverse_of: :connection
    embeds_many :headers, class_name: Setup::Parameter.to_s, inverse_of: :connection
    embeds_many :template_parameters, class_name: Setup::Parameter.to_s, inverse_of: :connection

    devise :database_authenticatable

    field :url, type: String
    field :number, as: :key, type: String
    field :token, type: String

    after_initialize :ensure_token

    accepts_nested_attributes_for :parameters, :headers, :template_parameters, allow_destroy: true

    validates_presence_of :url, :key, :token
    validates_uniqueness_of :token

    def ensure_token
      self.token ||= generate_token
    end

    def generate_number(options = {})
      options[:prefix] ||= 'C'
      super(options)
    end

    def conformed_url(options = {})
      conform_field_value(:url, options)
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
