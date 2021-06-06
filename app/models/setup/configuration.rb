module Setup
  class Configuration
    include CenitUnscoped
    include Setup::Singleton

    build_in_data_type.on_origin(:admin)

    deny :all

    field :_id, type: String, default: 'this'

    # Data Types
    belongs_to :email_data_type, class_name: Setup::DataType.to_s, inverse_of: nil

    #Tenants
    belongs_to :observer_tenant, class_name: Account.to_s, inverse_of: nil
    belongs_to :default_build_in_tenant, class_name: Account.to_s, inverse_of: nil

    before_save :check

    def check
      check_email_data_type
      check_default_build_in_tenant
    end

    def check!
      save
    end

    def check_email_data_type
      unless email_data_type.nil? || email_data_type.origin == :shared
        Setup::SystemReport.create(
          message: "Email data type #{email_data_type.custom_title} is not shared",
          type: :warning
        )
      end
    end

    def check_default_build_in_tenant
      unless default_build_in_tenant
        self.default_build_in_tenant = ::Tenant.create(
          name: a_build_in_tenant_name
        )
      end
    end

    def a_build_in_tenant_name
      name = base_name = 'Build-ins'
      c = 0
      while ::Tenant.where(name: name).exists?
        name = "#{base_name} (#{c += 1})"
      end
      name
    end
  end
end
