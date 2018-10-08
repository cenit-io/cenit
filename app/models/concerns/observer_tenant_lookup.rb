module ObserverTenantLookup
  extend ActiveSupport::Concern

  include EventLookup

  included do

    after_save do
      if (tenant = Setup::Configuration.singleton_record.observer_tenant)
        tenant.owner_switch do
          Mongoff::Model.after_save.call(self)
        end
      end
    end
  end
end
