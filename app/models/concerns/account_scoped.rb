module AccountScoped
  extend ActiveSupport::Concern
  included do
    store_in collection: Proc.new { tenant_collection_name }

    belongs_to :account, class_name: Account.to_s, inverse_of: nil

    before_validation { self.account = Account.current unless self.account }
    default_scope -> { with(collection: tenant_collection_name).where(Account.current ? {account: Account.current} : {}) }
  end

  module ClassMethods
    def validates_account_uniqueness_of(field)
      validates field, uniqueness: { scope: :account_id }
    end

    def tenant_collection_name
      name = to_s.collectionize
      name = "acc#{Account.current.id}_#{name}" if Account.current.present?
      name
    end
  end
end
