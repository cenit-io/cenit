module Setup
  class OauthAuthorization < Setup::BaseOauthAuthorization
    include CenitScoped

    BuildInDataType.regist(self).with(:namespace, :name, :provider, :client).referenced_by(:namespace, :name)

    field :access_token_secret, type: String
    field :realm, type: String

    auth_template_parameters oauth_token: :access_token,
                             oauth_token_secret: :access_token_secret,
                             consumer_key: ->(a) { a.client && a.client.attributes[:identifier]},
                             consumer_secret: ->(a) { a.client && a.client.attributes[:secret]}

    def build_auth_header
      '{% oauth_authorization %}'
    end

    def callback_key
      :oauth_callback
    end

    def create_http_client(options = {})
      if http_proxy = Cenit.http_proxy
        options[:proxy] ||= http_proxy
      end
      options[:request_token_url] ||= provider.request_token_endpoint
      options[:authorize_url] ||= provider.authorization_endpoint
      options[:access_token_url] ||= provider.token_endpoint
      OAuth::Consumer.new(client.attributes[:identifier], client.attributes[:secret], options)
    end

    def authorize_url(params)
      cenit_token = params.delete(:cenit_token)
      request_token = create_http_client.get_request_token(authorize_params(params))
      cenit_token.data[:request_token_secret] = request_token.secret if cenit_token
      request_token.authorize_url
    end

    def request_token(params)
      cenit_token = params.delete(:cenit_token)
      request_token = create_http_client.get_request_token(token_params(params))
      request_token.secret = cenit_token.data[:request_token_secret] if cenit_token
      request_token.token = params[:oauth_token]

      oauth_token = request_token.get_access_token(oauth_verifier: params[:oauth_verifier])

      self.access_token = oauth_token.token
      self.access_token_secret = oauth_token.secret
      self.realm_id = params['realmId'] if params['realmId']
      self.authorized_at = Time.now
    end

  end
end