module Setup
  class BaseOauthAuthorization
    include CenitScoped
    include NamespaceNamed
    include ClassHierarchyAware

    Setup::Models.exclude_actions_for self, :all

    BuildInDataType.regist(self).with(:name, :provider, :client).referenced_by(:namespace, :name)

    belongs_to :provider, class_name: Setup::BaseOauthProvider.to_s, inverse_of: nil
    belongs_to :client, class_name: Setup::OauthClient.to_s, inverse_of: nil

    field :access_token, type: String
    field :token_span, type: BigDecimal
    field :authorized_at, type: Time

    validates_presence_of :name, :provider, :client
    validates_uniqueness_of :name

    before_save :check_instance_type

    def check_instance_type
      if self.is_a?(Setup::OauthAuthorization) || self.is_a?(Setup::Oauth2Authorization)
        true
      else
        errors.add(:base, 'An authorization must be of type Oauth or Oauth2')
        false
      end
    end

    def ready_to_save?
      provider.present?
    end

    def can_be_restarted?
      provider.present?
    end

    def create_http_client(options = {})
      fail NotImplementedError
    end

    def callback_key
      fail NotImplementedError
    end

    def base_params
      {callback_key => "#{Cenit.oauth2_callback_site}/oauth2/callback"}
    end

    def authorize_params(params = {})
      params = base_params.merge(params)
      provider.parameters.each { |parameter| params[parameter.key.to_sym] = parameter.value }
      params
    end

    def token_params(params = {})
      params[:token_method] ||= provider.token_method
      base_params.merge(params)
    end

    def authorize_url(params)
      fail NotImplementedError
    end
  end
end