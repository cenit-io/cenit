module Setup
  class BaseOauthAuthorization < Setup::Authorization
    include CenitScoped
    include AuthorizationHeader

    abstract_class true

    BuildInDataType.regist(self).with(:namespace, :name, :client).referenced_by(:namespace, :name)

    belongs_to :client, class_name: Setup::OauthClient.to_s, inverse_of: nil

    field :access_token, type: String
    field :token_span, type: BigDecimal
    field :authorized_at, type: Time

    validates_presence_of :client

    def provider
      client && client.provider
    end

    def authorized?
      authorized_at.present?
    end

    def create_http_client(options = {})
      fail NotImplementedError
    end

    def callback_key
      fail NotImplementedError
    end

    def base_params
      { callback_key => "#{Cenit.oauth2_callback_site}/oauth2/callback" }
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