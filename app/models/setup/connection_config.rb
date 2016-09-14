module Setup
  class ConnectionConfig
    include CenitScoped
    include NumberGenerator

    deny :all
    allow :index, :show, :edit

    build_in_data_type

    belongs_to :connection, class_name: Setup::Connection.to_s, inverse_of: nil

    field :number, type: String
    field :token, type: String

    attr_readonly :connection

    validates_presence_of :connection

    after_initialize :ensure_token

    validates_presence_of :number, :token
    validates_uniqueness_of :token

    def read_attribute(name)
      (!(value = super).nil? &&

        (new_record? || !Setup::Connection.data_type.protecting?(name) ||
          (current_user = User.current) && current_user.owns?(Account.current_tenant)) &&

        value) || nil
    end

    def ensure_token
      if new_record? || token.blank?
        self.token = generate_token
      end
    end

    def generate_number(options = {})
      options[:prefix] ||= 'C'
      super(options)
    end

    class << self
      def config_fields
        %w(number token)
      end
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
