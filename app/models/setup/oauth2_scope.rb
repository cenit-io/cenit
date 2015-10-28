module Setup
  class Oauth2Scope
    include CenitUnscoped
    include CrossTenancy
    include CustomTitle

    Setup::Models.exclude_actions_for self, :all

    BuildInDataType.regist(self).referenced_by(:name, :provider)

    field :name, type: String
    field :description, type: String

    belongs_to :provider, class_name: Setup::Oauth2Provider.to_s, inverse_of: :scopes

    validates_presence_of :name, :provider
    validates_uniqueness_of :name, scope: :provider

    def scope_title
      provider && provider.custom_title
    end
  end
end