module Setup
  class BaseOauthAuthorization
    include CenitScoped

    Setup::Models.exclude_actions_for self, :all

    BuildInDataType.regist(self).referenced_by(:name).excluding(:refresh_token, :bearer_token)

    field :name, type: String

    belongs_to :provider, class_name: Setup::OauthProvider.to_s, inverse_of: nil
    belongs_to :client, class_name:  Setup::OauthClient.to_s, inverse_of: nil

    field :access_token, type: String
    field :token_span, type: BigDecimal
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