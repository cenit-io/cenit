module Api::V2UserHelper

  def create_user_and_account
    user = create(:user)
    account = Account.create(owner: user)
    user.account_ids = [account.id]
    user.save
    [user, account]
  end

  def v2_auth_headers(user, account)
    account.reload
    {
      'X-Tenant-Access-Key' => account.key,
      'X-Tenant-Access-Token' => account.token
    }
  end
  
  def v2_legacy_auth_headers(user, account)
    {
      'X-User-Access-Key' => account.key,
      'X-User-Access-Token' => account.token
    }
  end

end
