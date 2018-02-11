module Setup
  class Configuration
    include CenitUnscoped
    include Setup::Singleton
    include RailsAdmin::Models::Setup::ConfigurationAdmin

    build_in_data_type

    deny :all

    has_and_belongs_to_many :ecommerce_data_types, class_name: Setup::DataType.to_s, inverse_of: nil

    belongs_to :email_data_type, class_name: Setup::DataType.to_s, inverse_of: nil

    def warnings
      @warnings ||= []
    end

    before_save :check_eccomerce_data_types, :check_email_data_type

    def check_eccomerce_data_types
      ecommerce_data_types.where(:origin.ne => :shared).each do |data_type|
        warnings << "eCommerce data type #{data_type.custom_title} is not shared"
      end
      errors.blank?
    end

    def check_email_data_type
      warnings << "Email data type #{email_data_type.custom_title} is not shared" unless email_data_type.nil? || email_data_type.origin == :shared
      errors.blank?
    end
  end
end
