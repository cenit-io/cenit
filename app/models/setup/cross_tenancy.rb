module Setup
  module CrossTenancy
    extend ActiveSupport::Concern

    include Trackable

    included do

      field :shared, type: Boolean
      belongs_to :tenant, class_name: Account.to_s, inverse_of: nil

      before_save do
        changed_attributes.keys.each do |attr|
          reset_attribute!(attr) if %w(shared tenant tenant_id).include?(attr)
        end unless User.current.super_admin?
        self.tenant_id = creator.account_id if tenant_id.nil?
        self.shared = false if shared.nil?
        true
      end

      default_scope -> { User.current.super_admin? ? all : any_of({shared: true}, {tenant_id: Account.current.id}) }

    end
  end
end