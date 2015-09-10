module Setup
  class Oauth2Provider < Setup::BaseOauthProvider
    include CenitUnscoped

    Setup::Models.exclude_actions_for self, :all

    BuildInDataType.regist(self).referenced_by(:name)

    has_many :scopes, class_name: Setup::Oauth2Scope.to_s, inverse_of: :provider

    field :scope_separator, type: String

    validates_length_of :scope_separator, maximum: 1

    def create_http_client(authorization, options = {})
      super
      sep = scope_separator.blank? ? ' ' : scope_separator
      options =
        base_options.merge(authorize_url: authorization_endpoint,
                           token_url: token_endpoint,
                           scope: @object.scopes.collect { |scope| scope.name }.join(sep)).merge(options)
      client = OAuth2::Client.new(authorization.client.identifier,
                                  authorization.client.secret,
                                  options)
      if http_proxy = Cenit.http_proxy
        client.connection.proxy(http_proxy)
      end
      client
    end

    def request_token_for(authorization, params)
      client = create_http_client(authorization)
      token = client.auth_code.get_token(code, options)
      authorization.token_type = token.params['token_type']
      authorization.authorized_at =
        if time = token.params['created_at']
          Time.at(time)
        else
          Time.now
        end
      authorization.access_token = token.token
      authorization.token_span = token.expires_in
      authorization.refresh_token = token.refresh_token
    end
  end
end