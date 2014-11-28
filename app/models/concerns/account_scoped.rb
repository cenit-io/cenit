module AccountScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :account, class_name: 'Account'

<<<<<<< HEAD
    before_validation { self.account = Account.current }
    default_scope ->{ where(Account.current ? {account: Account.current} : {})   }
=======
    before_validation { self.account = Account.current unless self.account }
    default_scope ->{ where(Account.current ? {account: Account.current} : {}) }
>>>>>>> e342d9050fd0006c02f7434498813f6983407428
  end

end
