module Setup
  class BaseOauthAuthorization < Setup::Authorization
    include CenitScoped
    include AuthorizationHeader
    include Parameters

    abstract_class true

    build_in_data_type.with(:namespace, :name, :client, :parameters).referenced_by(:namespace, :name)

    belongs_to :client, class_name: Setup::OauthClient.to_s, inverse_of: nil

    parameters :parameters

    field :access_token, type: String
    field :token_span, type: BigDecimal
    field :authorized_at, type: Time

    validates_presence_of :client

    def expires_at
      authorized_at && token_span && authorized_at + token_span
    end

    def expires_in
      if (expires_at = self.expires_at)
        expires_at - Time.now
      end
    end

    def provider
      client && client.provider
    end

    def fresh_access_token
      (p = provider) && p.refresh_token(self)
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
      { callback_key => "#{Cenit.oauth2_callback_site}/oauth/callback" }
    end

    def authorize_params(params = {})
      params = base_params.merge(params)
      parameters.each { |parameter| params[parameter.key.to_sym] = parameter.value }
      params
    end

    def token_params(params = {})
      params[:token_method] ||= provider.token_method
      base_params.merge(params)
    end

    def authorize_url(params)
      fail NotImplementedError
    end

    def request_token!(params)
      request_token(params)
      save
    end

    def request_token(params)
      fail NotImplementedError
    end

    def cancel!
      cancel
      save
    end

    def cancel
      self.access_token = self.token_span = self.authorized_at = nil
    end

    def accept_callback?(params)
      fail NotImplementedError
    end
  end
end