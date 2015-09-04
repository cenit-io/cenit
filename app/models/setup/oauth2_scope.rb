module Setup
  class Oauth2Scope
    include CenitUnscoped

    Setup::Models.exclude_actions_for self, :all

    BuildInDataType.regist(self).referenced_by(:name)

    field :name, type: String
    field :description, type: String

    belongs_to :provider, class_name: Setup::Oauth2Provider.to_s, inverse_of: :scopes

    validates_presence_of :name, :provider

  end
end