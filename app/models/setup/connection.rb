module Setup
  class Connection
    include CenitScoped
    include NamespaceNamed
    include NumberGenerator
    include ParametersCommon

    BuildInDataType.regist(self).referenced_by(:namespace, :name).excluding(:connection_roles)

    embeds_many :parameters, class_name: Setup::Parameter.to_s, inverse_of: :connection
    embeds_many :headers, class_name: Setup::Parameter.to_s, inverse_of: :connection
    embeds_many :template_parameters, class_name: Setup::Parameter.to_s, inverse_of: :connection
    belongs_to :authorization, class_name: Setup::Authorization.to_s, inverse_of: nil
    field :authorization_handler, type: Boolean

    devise :database_authenticatable

    field :url, type: String
    field :number, as: :key, type: String
    field :token, type: String

    after_initialize :ensure_token

    accepts_nested_attributes_for :parameters, :headers, :template_parameters, allow_destroy: true

    validates_presence_of :url, :key, :token
    validates_uniqueness_of :token

    before_save :check_authorization

    def check_authorization
      if authorization.present?
        field = authorization_handler ? :template_parameters : :headers
        auth_params = authorization.class.send("auth_#{field}")
        conflicting_keys = send(field).select { |p| auth_params.has_key?(p.key) }.collect(&:key)
        if conflicting_keys.present?
          label = 'authorization ' + field.to_s.gsub('_', ' ')
          errors.add(:base, "#{label.capitalize} conflicts while authorization handler is #{authorization_handler ? '' : 'not'} checked")
          errors.add(field, "contains #{label} keys: #{conflicting_keys.to_sentence}")
          send(field).any_in(key: conflicting_keys).each { |p| p.errors.add(:key, "conflicts with #{label}") }
        end
      end
      errors.blank?
    end

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

    def other_headers_each(&block)
      authorization.each_header(&block) if authorization_handler && block
    end

    def other_template_parameters_each(&block)
      authorization.each_template_parameter(&block) if !authorization_handler && block
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
