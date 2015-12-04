module AccountTokenCommon
  extend ActiveSupport::Concern

  included do
    belongs_to :account, class_name: Account.to_s, inverse_of: nil

    before_create { self.account ||= Account.current }
  end

  def set_current_account
    Account.current = account if Account.current.nil?
    account
  end
end