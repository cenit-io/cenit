module Setup
  class OauthClient
    include CrossTenancy
    include CustomTitle

    BuildInDataType[self].including(:provider).referenced_by(:provider, :name).protecting(:identifier, :secret)

    field :name, type: String
    belongs_to :provider, class_name: Setup::BaseOauthProvider.to_s, inverse_of: :clients

    field :identifier, type: String
    field :secret, type: String

    validates_presence_of :provider, :name, :identifier, :secret
    validates_uniqueness_of :name, scope: :provider

    def scope_title
      provider && provider.custom_title
    end
  end
end