module Setup
  class BaseOauthProvider < AuthorizationProvider
    include RailsAdmin::Models::Setup::BaseOauthProviderAdmin

    abstract_class true

    build_in_data_type.referenced_by(:namespace, :name)

    field :response_type, type: String
    field :token_endpoint, type: String
    field :token_method, type: String

    field :refresh_token_strategy, type: String, default: :none.to_s
    belongs_to :refresh_token_algorithm, class_name: Setup::Algorithm.to_s, inverse_of: nil

    validates_presence_of :name, :response_type, :authorization_endpoint, :token_endpoint, :token_method
    validates_inclusion_of :response_type, in: ->(provider) { provider.response_type_enum }
    validates_inclusion_of :token_method, in: ->(provider) { provider.token_method_enum }
    validates_inclusion_of :refresh_token_strategy, in: ->(provider) { provider.refresh_token_strategy_enum }

    before_save do
      case refresh_token_strategy
      when :custom
        errors.add(:refresh_token_algorithm, "can't be blank") unless refresh_token_algorithm
      when :none
        if refresh_token_algorithm
          errors.add(:refresh_token_algorithm, 'not allowed')
          self.refresh_token_algorithm = nil
        end
      end
      errors.blank?
    end

    def response_type_enum
      ['code']
    end

    def token_method_enum
      %w(POST GET)
    end

    def refresh_token_strategy_enum
      [
        'Google v4',
        'Intuit Reconnect API V1',
        'Lazada REST API',
        'custom',
        'default',
        'none'
      ]
    end

    def refresh_token(authorization)
      if authorization.authorized?
        send(refresh_token_strategy.tr(' ', '_').underscore + '_refresh_token', authorization)
        authorization.access_token
      else
        fail "#{authorization.custom_title} not yet authorized"
      end
    end

    def none_refresh_token(authorization)
    end

    def custom_refresh_token(authorization)
      if (alg = refresh_token_algorithm)
        alg.run(authorization)
        authorization.save
      else
        fail "Refresh token algorithm is missing on #{custom_title}"
      end
    end

    def default_refresh_token(authorization)
      if (refresh_token = authorization.refresh_token) &&
        (authorization.authorized_at.nil? || (authorization.authorized_at + (authorization.token_span || 0) < Time.now - 60))
        fail 'Missing client configuration' unless authorization.client
        http_response = HTTMultiParty.post(
          authorization.token_endpoint,
          headers: { 'Content-Type' => 'application/x-www-form-urlencoded' },
          body: {
            grant_type: :refresh_token,
            refresh_token: refresh_token,
            client_id: authorization.client.get_identifier,
            client_secret: authorization.client.get_secret
          }.to_param
        )
        body = JSON.parse(http_response.body)
        if http_response.code == 200
          update_data = {
            authorized_at: Time.now,
            token_type: body['token_type'],
            access_token: body['access_token'],
            token_span: body['expires_in']
          }
          if (refresh_token = body['refresh_token'])
            update_data[:refresh_token] = refresh_token
          end
          authorization.update!(update_data)
        else
          fail "(response code #{http_response.code} - #{body['error']}) #{body['error_description']}"
        end
      end
    rescue Exception => ex
      Setup::SystemNotification.create_from(ex, "refreshing token for #{authorization.custom_title}")
      raise "Error refreshing token for #{authorization.custom_title}: #{ex.message}"
    end

    def google_v4_refresh_token(authorization)
      unless authorization.authorized_at + authorization.token_span > Time.now - 60
        fail 'Missing client configuration' unless authorization.client
        post = Setup::Connection.post('https://www.googleapis.com/oauth2/v4/token')
        http_response = post.submit(
          headers: { 'Content-Type' => 'application/x-www-form-urlencoded' },
          body: {
            grant_type: :refresh_token,
            refresh_token: authorization.refresh_token,
            client_id: authorization.client.get_identifier,
            client_secret: authorization.client.get_secret
          }.to_param,
          verbose_response: true
        )[:response]
        body = JSON.parse(http_response.body)
        if http_response.code == 200
          authorization.authorized_at = Time.now
          authorization.token_type = body['token_type']
          authorization.access_token = body['access_token']
          authorization.token_span = body['expires_in']
          authorization.save
        else
          fail "(response code #{http_response.code} - #{body['error']}) #{body['error_description']}"
        end
      end
    rescue Exception => ex
      raise "Error refreshing token for #{authorization.custom_title}: #{ex.message}"
    end

    def intuit_reconnect_api_v1_refresh_token(authorization)
      return unless authorization.authorized_at + 151.days < Time.now
      url = 'https://appcenter.intuit.com/api/v1/connection/reconnect'
      response = Setup::Connection.get(url).with(authorization).submit(http_proxy_address: Cenit.http_proxy_address,
                                                                       http_proxy_port: Cenit.http_proxy_port)
      xml_doc = Nokogiri::XML(response)
      if (oauth_token = xml_doc.root.element_children.detect { |e| e.name == 'OAuthToken' }) &&
        (oauth_token_secret = xml_doc.root.element_children.detect { |e| e.name == 'OAuthTokenSecret' })
        authorization.access_token = oauth_token.content
        authorization.access_token_secret = oauth_token_secret.content
        authorization.save
      else
        msg = 'An error occurs'
        if (error_message = xml_doc.root.element_children.detect { |e| e.name == 'ErrorMessage' })
          msg = error_message.content
        end
        if (error_code = xml_doc.root.element_children.detect { |e| e.name == 'ErrorCode' })
          msg += " (Error code #{error_code.content})"
        end
        fail msg
      end
    rescue Exception => ex
      raise "Error refreshing token for #{authorization.custom_title}: #{ex.message}"
    end

    def lazada_rest_api_refresh_token(authorization)
      unless authorization.authorized_at + authorization.token_span > Time.now - 60
        client = authorization.client
        fail 'Missing client configuration' unless client
        fail 'Missing OAuth provider configuration' unless authorization.provider
        token_endpoint_uri = URI.parse(authorization.token_endpoint)
        refresh_endpoint_uri = URI.parse('/rest/auth/token/refresh')
        refresh_endpoint_uri.scheme = token_endpoint_uri.scheme
        refresh_endpoint_uri.host = token_endpoint_uri.host
        get = Setup::Connection.get(refresh_endpoint_uri.to_s)
        params = { 'refresh_token' => authorization.refresh_token.to_s }
        Setup::LazadaAuthorization.sign_params(client, '/auth/token/refresh', params)
        http_response = get.submit(parameters: params, verbose_response: true)[:response]
        body = JSON.parse(http_response.body)
        if http_response.code == 200 && body['access_token']
          authorization.authorized_at = Time.now
          if (token_type = body['token_type'])
            authorization.token_type = token_type
          end
          authorization.access_token = body['access_token']
          authorization.token_span = body['expires_in']
          if (refresh_token = body['refresh_token'])
            authorization.refresh_token = refresh_token
          end
          authorization.save
        else
          fail body['message']
        end
      end
    rescue Exception => ex
      raise "Error refreshing token for #{authorization.custom_title}: #{ex.message}"
    end

    def client(name)
      Setup::OauthClient.where(provider_id: id, name: name).first
    end
  end
end
