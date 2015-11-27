module Setup
  module CrossTenancy
    extend ActiveSupport::Concern

    include Trackable

    included do

      BuildInDataType.regist(self).excluding(:shared, :tenant)

      field :shared, type: Boolean
      belongs_to :tenant, class_name: Account.to_s, inverse_of: nil

      before_save do
        changed_attributes.keys.each do |attr|
          reset_attribute!(attr) if %w(shared).include?(attr)
        end unless User.current.super_admin?
        self.tenant_id = creator.account_id if tenant_id.nil?
        self.shared = false if shared.nil? || !tenant.owner.super_admin?
        true
      end

      default_scope -> { User.current.super_admin? ? all : any_of({shared: true}, {creator_id: {'$in' => Account.current.users.collect(&:id)}}) }

      def read_attribute(name)
        (!(value = super).nil? && (!BuildInDataType[self.class].protecting?(name) || Account.current == creator.account || User.current.super_admin?) && value)|| nil
      end

    end
  end
end