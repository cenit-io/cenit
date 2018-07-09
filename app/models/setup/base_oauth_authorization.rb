module Setup
  class BaseOauthAuthorization < Setup::Authorization
    include CenitScoped
    include AuthorizationHeader
    include Parameters
    include WithTemplateParameters

    abstract_class true

    build_in_data_type.with(:namespace, :name, :client, :parameters, :template_parameters)
    build_in_data_type.referenced_by(:namespace, :name)

    belongs_to :client, class_name: Setup::OauthClient.to_s, inverse_of: nil

    parameters :parameters, :template_parameters

    field :access_token, type: String
    field :token_span, type: BigDecimal
    field :authorized_at, type: Time

    validates_presence_of :client

    def each_template_parameter(&block)
      return unless block
      template_parameters.each do |parameter|
        block.call(parameter.name, parameter.value)
      end
      method_missing(:each_template_parameter, &block)
    end

    def expires_at
      authorized_at && token_span && authorized_at + token_span
    end

    def expires_in
      if (expires_at = self.expires_at)
        expires_at.to_i - Time.now.to_i
      end
    end

    def provider
      client && client.provider
    end

    def authorization_endpoint
      provider && template_value_of(provider.authorization_endpoint)
    end

    def token_endpoint
      provider && template_value_of(provider.token_endpoint)
    end

    def token_method
      provider && provider.token_method
    end

    def fresh_access_token
      (p = provider) && p.refresh_token(self)
    end

    def authorized?
      authorized_at.present?
    end

    def create_http_client(_options = {})
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
      conformed_parameters.each { |key, value| params[key.to_sym] = value }
      params
    end

    def token_headers(headers = {}, template_parameters = {})
      client.conformed_request_token_headers(template_parameters).each do |key, value|
        key = key.to_sym
        headers[key] ||= value
      end
      headers
    end

    def token_params(params = {}, template_parameters = {})
      client.conformed_request_token_parameters(template_parameters).each do |key, value|
        key = key.to_sym
        params[key] ||= value
      end
      base_params.merge(params)
    end

    def authorize_url(_params)
      fail NotImplementedError
    end

    def request_token!(params)
      request_token(params)
      save
    end

    def request_token(_params)
      fail NotImplementedError
    end

    def cancel!
      cancel
      save
    end

    def cancel
      self.access_token = self.token_span = self.authorized_at = nil
    end

    def accept_callback?(_params)
      fail NotImplementedError
    end

  end
end
