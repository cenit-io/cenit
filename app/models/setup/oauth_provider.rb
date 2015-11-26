module Setup
  class OauthProvider < Setup::BaseOauthProvider
    include CenitUnscoped

    Setup::Models.exclude_actions_for self, :all

    BuildInDataType.regist(self).referenced_by(:namespace, :name).excluding(:tenant)

    field :request_token_endpoint, type: String

    validates_presence_of :request_token_endpoint
  end
end