module Setup
  module CrossOriginShared
    extend ActiveSupport::Concern

    include CenitScoped
    include CrossOrigin::CenitDocument
    include Trackable

    included do
      origins :default, -> { Cenit::MultiTenancy.tenant_model.current && :owner }, :shared

      build_in_data_type.excluding(:origin, :tenant)

      shared_deny :delete

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

    def track_history?
      (shared? || self.class.data_type.track_default_history) && super
    end

    def history_tracker_class
      tracker_class = Mongoid::History.tracker_class
      tracker_class.with(self.class.mongoid_root_class)
    end

    def history_tracks
      @history_tracks ||= history_tracker_class.where(scope: related_scope, association_chain: association_hash)
    end

    def track_history_for_action!(action)
      track_history_for_action(action)
      save
    end

    def track_history_for_action(action)
      if track_history_for_action?(action)
        current_version = (send(history_trackable_options[:version_field]) || 0) + 1
        send("#{history_trackable_options[:version_field]}=", current_version)
        history_tracker_class.create!(history_tracker_attributes(action.to_sym).merge(
          version: current_version,
          action: action.to_s,
          trackable: self,
          origin: origin))
      end
      clear_trackable_memoization
    end

    def not_shared?
      !shared?
    end

    def shared?
      origin != :default
    end

    def tenant_version
      if version && (pin = Setup::Pin.for(self)) && pin.version < version
        undo nil, from: pin.version + 1, to: version
      end
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

      def history_trackable_options
        @history_trackable_options ||= Mongoid::History.trackable_class_options[with(tenant: nil).collection_name.to_s.singularize.to_sym]
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
