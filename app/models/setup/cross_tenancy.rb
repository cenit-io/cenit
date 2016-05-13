module Setup
  module CrossTenancy
    extend ActiveSupport::Concern

    include CenitScoped
    include CrossOrigin::Document

    included do

      BuildInDataType.regist(self).excluding(:origin, :tenant)

      Setup::Models.exclude_actions_for self, :import, :translator_update, :convert, :send_to_flow, :copy, :new, :cross_share #TODO remove :new and :copy from excluded actions when fixing references sharing problem

      belongs_to :tenant, class_name: Account.to_s, inverse_of: nil

      before_save do
        if new_record?
          self.origin = :default
          self.tenant = Account.current
        end
        errors.blank?
      end

      before_destroy do
        unless origin == :default
          errors.add(:base, "#{try(:custom_title) || try(:name)} is shared")
        end
        errors.blank?
      end
    end

    def shared?
      origin == :shared
    end

    def read_attribute(name)
      (!(value = super).nil? && (new_record? || !BuildInDataType[self.class].protecting?(name) || Account.current == tenant) && value) || nil
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