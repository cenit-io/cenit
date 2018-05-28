module Setup
  class OauthAuthorization < Setup::BaseOauthAuthorization
    include CenitScoped
    include RailsAdmin::Models::Setup::OauthAuthorizationAdmin

    build_in_data_type.with(:namespace, :name, :provider, :client, :parameters, :template_parameters)
    build_in_data_type.referenced_by(:namespace, :name)

    field :access_token_secret, type: String
    field :realm_id, type: String

    auth_template_parameters oauth_token: ->(oauth_auth) { oauth_auth.fresh_access_token },
                             oauth_token_secret: :access_token_secret

    def request_token_endpoint
      provider && template_value_of(provider.request_token_endpoint)
    end

    def build_auth_header(template_parameters)
      self.class.auth_header(template_parameters.reverse_merge(consumer_key: client.get_identifier,
                                                               consumer_secret: client.get_secret,
                                                               oauth_token: access_token,
                                                               oauth_token_secret: access_token_secret))
    end

    def callback_key
      :oauth_callback
    end

    def create_http_client(options = {})
      if (http_proxy = Cenit.http_proxy)
        options[:proxy] ||= http_proxy
      end
      options[:request_token_url] ||= request_token_endpoint
      options[:authorize_url] ||= authorization_endpoint
      options[:access_token_url] ||= token_endpoint
      options[:http_method] ||= token_method.to_s.downcase
      OAuth::Consumer.new(client.get_identifier, client.get_secret, options)
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

    def accept_callback?(params)
      params[:oauth_token].present? && params[:oauth_verifier].present?
    end

    class << self

      def auth_header(template_parameters)
        template_parameters = template_parameters.with_indifferent_access

        consumer = OAuth::Consumer.new(template_parameters[:consumer_key],
                                       template_parameters[:consumer_secret],
                                       site: template_parameters[:url],
                                       scheme: :header)

        access_token = OAuth::AccessToken.from_hash(consumer,
                                                    oauth_token: template_parameters[:oauth_token],
                                                    oauth_token_secret: template_parameters[:oauth_token_secret])

        path = template_parameters[:path]
        if (query = template_parameters[:query]).present?
          path += '?' + query
        end
        path = '/' + path unless path.start_with?('/')

        if (content_type = template_parameters[:contentType])
          request = consumer.send(:create_http_request, template_parameters[:method], path, template_parameters[:body])
          request.content_type = content_type
          consumer.sign!(request, access_token, {})
        else
          request = consumer.create_signed_request(template_parameters[:method],
                                                   path,
                                                   access_token,
                                                   {},
                                                   template_parameters[:body])
        end
        request['authorization']
      end

    end
    
  end
end
