module Cenit
  class ActiveTenant
    include Mongoid::Document
    include RailsAdmin::Models::ActiveTenantAdmin

    belongs_to :tenant, class_name: Account.to_s, inverse_of: nil

    field :tasks, type: Integer, default: 0

    module MongoidAdapter
      extend self

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

      def set_tasks(tasks, tenant = Tenant.current)
        tenant &&
          ActiveTenant.find_or_create_by(tenant_id: tenant.id).update(tasks: tasks)
      end

      def each(&block)
        ActiveTenant.where(:tasks.gt => 0).each(&block)
      end

      def clean
        ActiveTenant.where(:tasks.lte => 0).delete_all
      end

      def clean_all
        ActiveTenant.collection.drop
      end

      def to_hash
        ActiveTenant.all.map { |active_tenant| [active_tenant.tenant_id.to_s, active_tenant.tasks] }.to_h
      end

      def total_count
        ActiveTenant.all.count
      end
    end

    module RedisAdapter
      extend self

      ACTIVE_TENANT_PREFIX = 'active_tenant_'

      def get(key)
        Cenit::Redis.get(key).to_i
      end

      def key_for(tenant)
        ACTIVE_TENANT_PREFIX + tenant.id
      end

      def tenant_id_from(key)
        key.match(/\A#{ACTIVE_TENANT_PREFIX}(.*)/)[1]
      end

      def all_keys
        Cenit::Redis.keys("#{ACTIVE_TENANT_PREFIX}*")
      end

      def active_count
        all_keys.inject(0) do |sum, key|
          sum + (get(key) > 0 ? 1 : 0)
        end
      end

      def tasks_for(tenant = Tenant.current)
        (tenant && get(key_for(tenant))) || 0
      end

      def inc_tasks_for(tenant = Tenant.current)
        tenant && Cenit::Redis.incr(key_for(tenant))
      end

      def dec_tasks_for(tenant = Tenant.current)
        tenant &&
          (Cenit::Redis.decr(key = key_for(tenant)) <= 0) &&
          Cenit::Redis.del(key)
      end

      def set_tasks(tasks, tenant = Tenant.current)
        tenant && Cenit::Redis.set(key_for(tenant), tasks.to_i)
      end

      def each(&block)
        all_keys.each do |key|
          tasks = get(key)
          next unless tasks > 0
          block.call(tenant_id: tenant_id_from(key), tasks: tasks)
        end
      end

      def clean
        keys = all_keys.select { |key| get(key) <= 0 }
        Cenit::Redis.del *keys if keys.count > 0
      end

      def clean_all
        keys = all_keys
        Cenit::Redis.del *keys if keys.count > 0
      end

      def to_hash
        all_keys.map { |key| [tenant_id_from(key), get(key)] }.to_h
      end

      def total_count
        all_keys.count
      end
    end

    class << self

      def adapter
        @adapter ||=
          if Cenit::Redis.client?
            RedisAdapter
          else
            MongoidAdapter
          end
      end

      delegate :active_count,
               :total_count,
               :tasks_for,
               :inc_tasks_for,
               :dec_tasks_for,
               :each,
               :set_tasks,
               :clean,
               :clean_all,
               :to_hash,

               to: :adapter

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
end
