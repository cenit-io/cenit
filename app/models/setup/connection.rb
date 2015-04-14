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

    validates_uniqueness_of :name
    accepts_nested_attributes_for :parameters, :headers, :template_parameters

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

    def conformed_url
      conforms(url)
    end

    def conforms(str)
      s = ''
      tokens = str.split('{{')
      tokens.shift if tokens.first.blank?
      tokens.each do |token|
        if i = token.index('}}')
          s += '#{' + token[0, i] + token.from(i+2) + '}'
        else
          s += token
        end
      end
      obj = Object.new
      m = 'def m ;'
      template_parameters_hash.each { |key, value| m += "#{key} = '#{value}';" }
      m += "\"#{s}\";end"
      obj.class_eval(m)
      obj.m.gsub("\n", '')
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
