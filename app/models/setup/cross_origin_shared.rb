module Setup
  module CrossOriginShared
    extend ActiveSupport::Concern

    include CenitScoped
    include CrossOrigin::Document
    include Trackable

    included do

      origins :shared

      build_in_data_type.excluding(:origin, :tenant)

      shared_allow :edit
      shared_deny :delete

      belongs_to :owner, class_name: User.to_s, inverse_of: nil

      before_save do
        if new_record?
          self.origin = :default
          self.owner = User.current
        end
        errors.blank?
      end

      before_destroy do
        unless origin == :default
          errors.add(:base, "#{try(:custom_title) || try(:name) || "#{self.class}##{id}"} is shared")
        end
        errors.blank?
      end
    end

    def track_history?
      origin == :shared && super
    end

    def history_tracker_class
      tracker_class = Mongoid::History.tracker_class
      tracker_class.with(collection: "#{collection_name.to_s.singularize}_#{tracker_class.collection_name}")
    end

    def history_tracks
      @history_tracks ||= history_tracker_class.where(scope: related_scope, association_chain: association_hash)
    end

    def track_history_for_action(action)
      if track_history_for_action?(action)
        current_version = (send(history_trackable_options[:version_field]) || 0) + 1
        send("#{history_trackable_options[:version_field]}=", current_version)
        history_tracker_class.create!(history_tracker_attributes(action.to_sym).merge(version: current_version, action: action.to_s, trackable: self))
      end
      clear_trackable_memoization
    end

    def shared?
      origin == :shared
    end

    def account_version
      if version && (pin = Setup::PinnedVersion.for(self)) && pin.version < version
        undo nil, from: pin.version + 1, to: version
      end
      self
    end

    def read_attribute(name)
      (!(value = super).nil? &&

        (new_record? || !BuildInDataType[self.class].protecting?(name) ||
          (current_user = User.current) &&
            (current_user == owner ||
              current_user.account_id == owner.account_id ||
              (current_user.super_admin? && owner.super_admin?))) &&

        value) || nil
    end

    module ClassMethods

      def history_trackable_options
        @history_trackable_options ||= Mongoid::History.trackable_class_options[with(account: nil).collection_name.to_s.singularize.to_sym]
      end

      def super_count
        current_account = Account.current
        Account.current = nil
        c = 0
        Account.each do |account|
          Account.current = account
          c += where(origin: :default).count
        end
        Account.current = current_account
        c + where(origin: :shared).count
      end
    end
  end
end