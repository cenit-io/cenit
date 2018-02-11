module Setup
  class Configuration
    include CenitUnscoped
    include Setup::Singleton
    include RailsAdmin::Models::Setup::ConfigurationAdmin

    build_in_data_type

    deny :all

    has_and_belongs_to_many :ecommerce_data_types, class_name: Setup::DataType.to_s, inverse_of: nil
  end
end
