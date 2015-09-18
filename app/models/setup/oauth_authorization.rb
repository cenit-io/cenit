module Setup
  class OauthAuthorization < Setup::BaseOauthAuthorization
    include CenitScoped

    Setup::Models.exclude_actions_for self, :all

    BuildInDataType.regist(self).referenced_by(:name).excluding(:refresh_token, :bearer_token)


    field :access_token_secret, type: String
    field :realm, type: String

  end
end