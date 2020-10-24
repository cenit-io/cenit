module Setup
  class Configuration
    include CenitUnscoped
    include Setup::Singleton

    build_in_data_type

    deny :all

    field :_id, type: String, default: 'this'

    # Data Types
    has_and_belongs_to_many :ecommerce_data_types, class_name: Setup::DataType.to_s, inverse_of: nil
    belongs_to :email_data_type, class_name: Setup::DataType.to_s, inverse_of: nil

    # Home Sections
    field :social_networks, type: Array, default: -> { default_home_section(:social_networks) }
    field :home_services_menu, type: Array, default: -> { default_home_section(:home_services_menu) }
    field :home_services, type: Array, default: -> { default_home_section(:home_services) }
    field :home_explore_menu, type: Array, default: -> { default_home_section(:home_explore_menu) }
    field :home_integrations, type: Array, default: -> { default_home_section(:home_integrations) }
    field :home_features, type: Array, default: -> { default_home_section(:home_features) }

    belongs_to :observer_tenant, class_name: Account.to_s, inverse_of: nil

    def warnings
      @warnings ||= []
    end

    before_save :check_eccomerce_data_types, :check_email_data_type

    def check_eccomerce_data_types
      ecommerce_data_types.where(:origin.ne => :shared).each do |data_type|
        warnings << "eCommerce data type #{data_type.custom_title} is not shared"
      end
      abort_if_has_errors
    end

    def check_email_data_type
      warnings << "Email data type #{email_data_type.custom_title} is not shared" unless email_data_type.nil? || email_data_type.origin == :shared
      abort_if_has_errors
    end

    def default_home_sections
      @deafult_home_sections ||=
        begin
          JSON.parse(File.read('config/default_home_sections.json'))
        rescue
          {}
        end
    end

    def default_home_section(name)
      default_home_sections[name.to_s]
    end
  end
end
