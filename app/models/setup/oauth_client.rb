module Setup
  class OauthClient
    include CenitUnscoped

    Setup::Models.exclude_actions_for self, :all

    BuildInDataType.regist(self).referenced_by(:name)

    field :name, type: String

    belongs_to :provider, class_name: Setup::BaseOauthProvider.to_s, inverse_of: :clients

    field :identifier, type: String
    field :secret, type: String

    validates_presence_of :name, :provider, :identifier, :secret
  end
end