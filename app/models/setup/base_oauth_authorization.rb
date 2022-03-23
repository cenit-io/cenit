module Setup
  class BaseOauthAuthorization < Setup::Authorization
    include CenitScoped
    include AuthorizationHeader
    include CallbackAuthorization

    abstract_class true

    build_in_data_type.referenced_by(:namespace, :name)

    field :access_token, type: String
    field :token_span, type: BigDecimal

    def expires_at
      authorized_at && token_span && authorized_at + token_span.seconds
    end

    def expires_in
      if (expires_at = self.expires_at)
        expires_at.to_i - Time.now.to_i
      end
    end

    def token_endpoint
      provider && template_value_of(provider.token_endpoint)
    end

    def token_method
      provider&.token_method
    end

    def fresh_access_token
      (p = provider) && p.refresh_token(self)
    end

    def create_http_client(_options = {})
      fail NotImplementedError
    end

    def token_headers(headers = {}, template_parameters = {})
      client.conformed_request_token_headers(template_parameters).each do |key, value|
        key = key.to_s
        headers[key] ||= value
      end
      headers
    end

    def token_params(params = {}, template_parameters = {})
      client.conformed_request_token_parameters(template_parameters).each do |key, value|
        key = key.to_s
        params[key] ||= value
      end
      callback_params.merge(params)
    end


    def request_token!(params)
      request_token(params)
      save
    end

    def request_token(_params)
      fail NotImplementedError
    end

    def resolve(params)
      request_token(params)
    end

    def cancel
      self.access_token = self.token_span = nil
      super
    end
  end
end
