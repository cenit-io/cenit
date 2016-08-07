module AccountTokenCommon
  extend ActiveSupport::Concern

  included do
    belongs_to :account, class_name: Account.to_s, inverse_of: nil

    before_create { self.account ||= Account.current }
  end

  def set_current_account!
    set_current_account(force: true)
  end

  def set_current_account(options = {})
    Account.current = account if Account.current.nil? || options[:force]
    account
  end
end