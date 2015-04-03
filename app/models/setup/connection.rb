module Setup
  class Connection
    include CenitScoped
    include NumberGenerator

    BuildInDataType.regist(self).referenced_by(:name)

    has_and_belongs_to_many :connection_roles, class_name: Setup::ConnectionRole.to_s, inverse_of: :connections

    embeds_many :parameters, class_name: Setup::Parameter.to_s, inverse_of: :connection
    embeds_many :headers, class_name: Setup::Parameter.to_s, inverse_of: :connection
    embeds_many :template_parameters, class_name: Setup::Parameter.to_s, inverse_of: :connection

    devise :database_authenticatable

    field :name, type: String
    field :url, type: String
    field :number, as: :key, type: String
    field :token, type: String

    after_initialize :ensure_token

    validates_account_uniqueness_of :name
    accepts_nested_attributes_for :parameters, :headers, :template_parameters

    validates_presence_of :name, :url, :key, :token
    validates_account_uniqueness_of :token

    def ensure_token
      self.token ||= generate_token
    end

    def generate_number(options = {})
      options[:prefix] ||= 'C'
      super(options)
    end

    def template_parameters_hash
      hash = {}
      template_parameters.each_char { |p| h[p.key] = p.value }
      hash
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
