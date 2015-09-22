module Setup
  class Oauth2Authorization < Setup::BaseOauthAuthorization
    include CenitScoped

    Setup::Models.exclude_actions_for self, :all

    BuildInDataType.regist(self).referenced_by(:name).excluding(:refresh_token, :bearer_token)

    has_and_belongs_to_many :scopes, class_name:  Setup::Oauth2Scope.to_s, inverse_of: nil

    field :refresh_token, type: String
    field :token_type, type: String

  end
end