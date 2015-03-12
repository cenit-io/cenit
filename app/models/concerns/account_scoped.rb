module AccountScoped
  extend ActiveSupport::Concern
  included do
    belongs_to :account, class_name: Account.to_s, inverse_of: nil

    before_validation { self.account = Account.current unless self.account }
    default_scope -> { where(Account.current ? {account: Account.current} : {}) }
  end

  module ClassMethods

    def validates_account_uniqueness_of(field)
      validates field, uniqueness: { scope: :account_id }
    end
  end
end
