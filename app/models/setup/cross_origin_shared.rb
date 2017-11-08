module Setup
  module CrossOriginShared
    extend ActiveSupport::Concern

    include CenitScoped
    include CrossOrigin::CenitDocument
    include Mongoid::Userstamp
    include Mongoid::Tracer

    TRACING_IGNORE_ATTRIBUTES = [:created_at, :updated_at, :creator_id, :updater_id, :tenant_id, :origin]

    included do
      origins :default, -> { Cenit::MultiTenancy.tenant_model.current && :owner }, :shared

      build_in_data_type.excluding(:origin, :tenant)

      shared_deny :delete

      trace_ignore TRACING_IGNORE_ATTRIBUTES

      belongs_to :tenant, class_name: Cenit::MultiTenancy.tenant_model_name, inverse_of: nil

      before_validation :validates_before

      before_destroy :validates_for_destroy
    end

    def validates_for_destroy
      unless origin == :default
        errors.add(:base, "#{try(:custom_title) || try(:name) || "#{self.class}##{id}"} is shared")
      end
      errors.blank?
    end

    def validates_before
      self.tenant = Account.current if new_record?
    end

    def tracing?
      (shared? || self.class.data_type.trace_on_default) && super
    end

    def trace_action_attributes(action = nil)
      attrs = super
      attrs[:origin] = origin
      attrs
    end

    def trace_model
      super.with(self.class.mongoid_root_class)
    end

    def not_shared?
      !shared?
    end

    def shared?
      origin != :default
    end

    def tenant_version
      # if version && (pin = Setup::Pin.for(self)) && pin.version < version
      #   undo nil, from: pin.version + 1, to: version
      # end
      self
    end

    def read_attribute(name)
      if !(value = super).nil? &&
         (new_record? || !self.class.build_in_data_type.protecting?(name) ||
         (current_user = User.current) &&
         (current_user.account_ids.include?(tenant_id) ||
         (current_user.super_admin? && tenant.super_admin?)))
        value
      else
        nil
      end
    end

    def [](name)
      read_attribute(name)
    end

    module ClassMethods

      def shared_deny(*actions)
        Setup::Models.shared_excluded_actions_for self, *actions
      end

      def shared_allow(*actions)
        Setup::Models.shared_allowed_actions_for self, *actions
      end

      def clear_config_for(tenant, ids)
        clear_pins_for(tenant, ids)
      end

      def clear_pins_for(tenant, ids)
        Setup::Pin.with(tenant).where(model: mongoid_root_class, :record_id.in => ids).delete_all
      end

      def super_count
        # current_account = Account.current
        # Account.current = nil
        # c = 0
        # Account.each do |account|
        #   Account.current = account
        #   c += where(origin: :default).count
        # end
        # Account.current = current_account
        # c + where(origin: :shared).count
        where(:origin.ne => :default).count
      end

    end

  end
end
