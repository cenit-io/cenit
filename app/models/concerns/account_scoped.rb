module AccountScoped 
  extend ActiveSupport::Concern

  included do
    belongs_to :account

    before_validation { self.account = Account.current } 
    default_scope ->{ where(account: Account.current) }
  end

end