module Setup
  class OauthClient
    include CenitUnscoped
    include MandatoryNamespace
    include CrossTenancy

    Setup::Models.exclude_actions_for self, :all

    BuildInDataType[self].referenced_by(:namespace, :name).protecting(:identifier, :secret)

    belongs_to :provider, class_name: Setup::BaseOauthProvider.to_s, inverse_of: :clients

    field :identifier, type: String
    field :secret, type: String

    validates_presence_of :provider, :identifier, :secret
  end
end