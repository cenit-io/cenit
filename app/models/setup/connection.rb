module Setup
  class Connection
    include CenitCommon
    include NumberGenerator

    BuildInDataType.regist(self)

    embeds_many :url_parameters, class_name: Setup::Parameter.to_s, inverse_of: :connection
    embeds_many :headers, class_name: Setup::Parameter.to_s, inverse_of: :connection
    
    devise :database_authenticatable

    field :name, type: String
    field :url, type: String
    field :number, as: :key, type: String
    field :token, type: String

    after_initialize :ensure_token

    accepts_nested_attributes_for :url_parameters, :headers

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
