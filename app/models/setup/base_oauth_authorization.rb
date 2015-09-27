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

    before_save :check_instance_type

    def check_instance_type
      if self.is_a?(Setup::Oauth2Authorization) || self.is_a?(Setup::Oauth2Authorization)
        true
      else
        errors.add(:base, 'An authorization must be of type OAuth or OAuth2')
        false
      end
    end

    def ready_to_save?
      provider.present?
    end

    def can_be_restarted?
      provider.present?
    end
  end
end