module Setup
  class Oauth2Provider < Setup::BaseOauthProvider
    include CenitUnscoped

    BuildInDataType.regist(self).referenced_by(:namespace, :name).excluding(:shared, :tenant, :clients)

    field :scope_separator, type: String

    validates_length_of :scope_separator, maximum: 1
  end
end