module Setup
  class OauthAccessGrant
    include CenitScoped

    Setup::Models.exclude_actions_for(self, :all)
    Setup::Models.include_actions_for(self, :index, :delete)

    belongs_to :application_id, class_name: ApplicationId.to_s, inverse_of: nil
    field :scope, type: String

    before_destroy do
      [
        OauthAccessToken,
        OauthRefreshToken
      ].each do |oauth_token_model|
        oauth_token_model.where(account: Account.current, application_id: application_id).delete_all
      end
      true
    end
  end
end