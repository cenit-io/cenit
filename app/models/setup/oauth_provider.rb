module Setup
  class OauthProvider < Setup::BaseOauthProvider
    include CenitUnscoped

    Setup::Models.exclude_actions_for self, :all

    BuildInDataType.regist(self).referenced_by(:name)

    field :request_token_endpoint, type: String

    validates_presence_of :request_token_endpoint

    def create_http_client(authorization, options = {})
      super
      options =
        base_options.merge(request_token_url: request_token_endpoint,
                           authorize_url: authorization_endpoint,
                           access_token_url: token_endpoint,
                           http_method: token_method.to_s.to_sym).merge(options)
      client = OAuth::Consumer.new(authorization.client.identifier,
                                   authorization.client.secret,
                                   options)
      @session[:oauth_state] = options[:state] if @session
      client
    end

    def request_token_for(authorization, params)
      client = create_http_client(authorization, oauth_verifier: params[:oauth_verifier])

      oauth_token = client.get_access_token(option)

      authorization.access_token = oauth_token.token
      authorization.access_token_secret = oauth_token.secret
      authorization.realm_id = params['realmId'] if params['realmId']
      authorization.authorized_at = Time.now
    end
  end
end