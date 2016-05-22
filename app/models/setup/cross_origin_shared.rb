module Setup
  module CrossOriginShared
    extend ActiveSupport::Concern

    include CenitScoped
    include CrossOrigin::Document

    included do

      origins :shared

      BuildInDataType.regist(self).excluding(:origin, :tenant)

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

    def shared?
      origin == :shared
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