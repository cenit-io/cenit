module AccountScoped
  extend ActiveSupport::Concern
  included do
    belongs_to :account, class_name: 'Account'

    before_validation { self.account = Account.current unless self.account }
    default_scope -> { where(Account.current ? {account: Account.current} : {}) }
  end
end
