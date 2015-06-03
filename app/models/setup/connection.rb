module Setup
  class Connection
    include CenitScoped
    include NumberGenerator

    BuildInDataType.regist(self).referenced_by(:name).excluding(:connection_roles)

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

    validates_uniqueness_of :name
    accepts_nested_attributes_for :parameters, :headers, :template_parameters, allow_destroy: true

    validates_presence_of :name, :url, :key, :token
    validates_uniqueness_of :token

    def ensure_token
      self.token ||= generate_token
    end

    def generate_number(options = {})
      options[:prefix] ||= 'C'
      super(options)
    end

    def template_parameters_hash
      hash = {}
      template_parameters.each { |p| hash[p.key] = p.value }
      hash
    end

    def conformed_url(options = {})
      @url_template ||= Liquid::Template.parse(url)
      @url_template.render(options.merge(template_parameters_hash))
    end

    def conformed_parameters(options = {})
      conforms(:parameters, options)
    end

    def conformed_headers(options = {})
      conforms(:headers, options)
    end

    private

    def generate_token
      loop do
        token = Devise.friendly_token
        break token unless Setup::Connection.where(token: token).first
      end
    end

    def conforms(field, options = {})
      unless templates = instance_variable_get(var = "@_#{field}_templates".to_sym)
        templates = {}
        send(field).each { |p| templates[p.key] = Liquid::Template.parse(p.value) }
        instance_variable_set(var, templates)
      end
      hash = {}
      send(field).each { |p| hash[p.key] = templates[p.key].render(options.merge(template_parameters_hash)) }
      hash
    end

  end
end
