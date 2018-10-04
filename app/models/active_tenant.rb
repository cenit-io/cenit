class ActiveTenant
  include Mongoid::Document
  include RailsAdmin::Models::ActiveTenantAdmin

  belongs_to :tenant, class_name: Account.to_s, inverse_of: nil

  field :tasks, type: Integer, default: 0

  class << self

    def tasks_for(tenant = Tenant.current)
      if tenant && (record = where(tenant_id: tenant.id).first)
        record.tasks
      else
        0
      end
    end

    def inc_tasks_for(tenant = Tenant.current)
      return unless tenant
      find_or_create_by(tenant_id: tenant.id)
      collection.find(tenant_id: tenant.id).update_one('$inc' => { tasks: 1 })
    end

    def dec_tasks_for(tenant = Tenant.current)
      return unless tenant
      collection.find(tenant_id: tenant.id).update_one('$inc' => { tasks: -1 })
    end
  end
end
