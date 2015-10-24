module Setup
  class Oauth2Provider < Setup::BaseOauthProvider
    include CenitUnscoped

    Setup::Models.exclude_actions_for self, :all

    BuildInDataType.regist(self).referenced_by(:namespace, :name)

    has_many :scopes, class_name: Setup::Oauth2Scope.to_s, inverse_of: :provider

    field :scope_separator, type: String

    validates_length_of :scope_separator, maximum: 1
  end
end