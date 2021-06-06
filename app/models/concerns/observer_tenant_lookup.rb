module ObserverTenantLookup
  extend ActiveSupport::Concern

  include EventLookup

  included do
    before_save do
      @_changed_before_save = changed?
    end

    after_save :track_observer
  end

  def track_observer
    if track_observer? && (tenant = Setup::Configuration.singleton_record.observer_tenant)
      tenant.owner_switch do
        Mongoff::Model.after_save.call(self)
      end
    end
  end

  def track_observer?
    @_changed_before_save
  end
end
