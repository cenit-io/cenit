module Setup
  module CrossTenancy
    extend ActiveSupport::Concern

    include Trackable

    included do

      BuildInDataType.regist(self).excluding(:shared, :tenant)

      Setup::Models.exclude_actions_for self, :import, :translator_update, :convert, :send_to_flow, :copy, :new #TODO remove :new and :copy from excluded actions when fixing references sharing problem

      field :shared, type: Boolean
      belongs_to :tenant, class_name: Account.to_s, inverse_of: nil

      before_save do
        changed_attributes.keys.each do |attr|
          reset_attribute!(attr) if %w(shared).include?(attr)
        end unless Account.current.super_admin?
        self.tenant_id = creator.account_id if tenant_id.nil?
        self.shared = false if shared.nil? || !tenant.owner.super_admin?
        true
      end

      before_destroy do
        if shared
          errors.add(:base, "#{try(:custom_title) || try(:name)} is shared")
        end
        errors.blank?
      end

      default_scope -> { Account.current.super_admin? ? all : any_of({ shared: true }, { tenant_id: Account.current.id }) }
    end

    def read_attribute(name)
      (!(value = super).nil? && (!BuildInDataType[self.class].protecting?(name) || Account.current == creator.account || Account.current.super_admin?) && value)|| nil
    end
  end
end