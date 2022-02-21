module Setup
  class ConnectionConfig
    include CenitScoped
    include CredentialsGenerator

    build_in_data_type

    belongs_to :connection, class_name: Setup::Connection.to_s, inverse_of: nil, autosave: false

    attr_readonly :connection

    validates_presence_of :connection
    validates_uniqueness_of :connection

    def read_raw_attribute(name)
      if !(value = super).nil? && (new_record? || !Setup::Connection.data_type.protecting?(name) ||
          ((current_user = User.current) && current_user.owns?(Account.current_tenant)))
        value
      else
        nil
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
  end
end
