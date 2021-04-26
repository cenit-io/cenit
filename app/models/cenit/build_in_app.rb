module Cenit
  class BuildInApp < ::Setup::OauthClient
    include App

    origins :admin

    default_origin :admin

    build_in_data_type.with(:namespace, :name, :provider, :slug, :application_parameters)
    build_in_data_type.referenced_by(:namespace, :name, :_type).and(
      properties: {
        configuration: {
          type: 'object'
        }
      }
    )

    deny :delete

    belongs_to :tenant, class_name: Tenant.name, inverse_of: nil

    before_create :check_tenant

    def tracing?
      false
    end

    def check_tenant
      unless tenant
        self.tenant = Tenant.find_or_create_by!(name: name)
        application_id.update(tenant_id: tenant_id)
      end
      yield(self) if block_given?
    end

    def app_module
      "#{namespace}::#{name}".constantize
    rescue
      nil
    end

    def key
      app_module.app_key
    end

    class << self

      def stored_properties_on(record)
        stored = %w(namespace name slug provider identifier secret origin created_at updated_at)
        %w(application_parameters).each { |f| stored << f if record.send(f).present? }
        stored << 'configuration'
        stored
      end
    end
  end
end
