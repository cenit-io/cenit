module Setup
  class OauthProvider < Setup::BaseOauthProvider
    include CenitUnscoped

    BuildInDataType.regist(self).referenced_by(:namespace, :name).excluding(:shared)

    field :request_token_endpoint, type: String

    validates_presence_of :request_token_endpoint
  end
end