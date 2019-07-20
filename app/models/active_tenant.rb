class ActiveTenant
  include Mongoid::Document
  include RailsAdmin::Models::ActiveTenantAdmin

  belongs_to :tenant, class_name: Account.to_s, inverse_of: nil

  field :tasks, type: Integer, default: 0

  module MongoidAdapter
    extends self

    def active_count
      ActiveTenant.where(:tasks.gt => 0).count
    end

    def tasks_for(tenant = Tenant.current)
      if tenant && (record = ActiveTenant.where(tenant_id: tenant.id).first)
        record.tasks
      else
        0
      end
    end

    def inc_tasks_for(tenant = Tenant.current)
      return unless tenant
      ActiveTenant.find_or_create_by(tenant_id: tenant.id)
      ActiveTenant.collection.find(tenant_id: tenant.id).update_one('$inc' => { tasks: 1 })
    end

    def dec_tasks_for(tenant = Tenant.current)
      return unless tenant
      ActiveTenant.collection.find(tenant_id: tenant.id).update_one('$inc' => { tasks: -1 })
    end

    def each(&block)
      ActiveTenant.where(:tasks.gt => 0).each(&block)
    end

    def clean
      ActiveTenant.where(:tasks.lte => 0).delete_all
    end
  end

  module RedisAdapter
    extends self

    ACTIVE_TENANT_PREFIX = 'active_tenant_'

    def key_for(tenant)
      ACTIVE_TENANT_PREFIX + tenant.id
    end

    def tenant_id_from(key)
      key.match(/\A#{ACTIVE_TENANT_PREFIX}(*)/)[1]
    end

    def all_keys
      Cenit::Redis.keys("#{ACTIVE_TENANT_PREFIX}*")
    end

    def active_count
      all_keys.inject(0) do |sum, key|
        sum + (Cenit::Redis.get(key) > 0 ? 1 : 0)
      end
    end

    def tasks_for(tenant = Tenant.current)
      (tenant && Cenit::Redis.get(key_for(tenant))) || 0
    end

    def inc_tasks_for(tenant = Tenant.current)
      tenant && Cenit::Redis.incr(key_for(tenant))
    end

    def dec_tasks_for(tenant = Tenant.current)
      tenant && Cenit::Redis.decr(key_for(tenant))
    end

    def each(&block)
      all_keys.each do |key|
        tasks = Cenit::Redis.get(key)
        next unless tasks > 0
        block.call(tenant_id: tenant_id_from(key), tasks: tasks)
      end
    end

    def clean
      Cenit::Redis.del *(all_keys.select { |key| Cenit::Redis.get(key) <= 0 })
    end
  end

  class << self

    @adapter =
      if Cenit::Redis.client?
        RedisAdapter
      else
        MongoidAdapter
      end

    def adapter
      @adapter
    end

    delegate :active_count, :tasks_for, :inc_tasks_for, :dec_tasks_for, :each, :clean, to: :adapter

    def tasks_for_current
      tasks_for
    end

    def inc_tasks_for_current
      inc_tasks_for
    end

    def dec_tasks_for_current
      dec_tasks_for
    end
  end
end
