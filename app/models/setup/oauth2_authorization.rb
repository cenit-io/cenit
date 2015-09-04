module Setup
  class Oauth2Authorization
    include CenitScoped

    Setup::Models.exclude_actions_for self, :all

    BuildInDataType.regist(self).referenced_by(:name).excluding(:refresh_token, :bearer_token)

    field :name, type: String

    belongs_to :provider, class_name: Setup::Oauth2Provider.to_s, inverse_of: nil
    belongs_to :client, class_name:  Setup::Oauth2Client.to_s, inverse_of: nil
    has_and_belongs_to_many :scopes, class_name:  Setup::Oauth2Scope.to_s, inverse_of: nil

    field :refresh_token, type: String
    field :access_token, type: String
    field :token_type, type: String
    field :token_span, type: Long
    field :authorized_at, type: Time

    validates_presence_of :name, :provider, :client

    def ready_to_save?
      provider.present?
    end

    def can_be_restarted?
      provider.present?
    end
  end
end