module Setup
  class BaseOauthProvider
    include SharedEditable
    include MandatoryNamespace
    include ClassHierarchyAware
    include BuildIn
    include RailsAdmin::Models::Setup::BaseOauthProviderAdmin

    origins origins_config, :cenit

    abstract_class true

    build_in_data_type.referenced_by(:namespace, :name)

    field :response_type, type: String
    field :authorization_endpoint, type: String
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
      unless authorization.authorized_at + authorization.token_span > Time.now - 60
        fail 'Missing client configuration' unless authorization.client
        http_response = HTTMultiParty.post(authorization.token_endpoint,
                                           headers: { 'Content-Type' => 'application/x-www-form-urlencoded' },
                                           body: {
                                             grant_type: :refresh_token,
                                             refresh_token: authorization.refresh_token,
                                             client_id: authorization.client.get_identifier,
                                             client_secret: authorization.client.get_secret
                                           }.to_param)
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

  end
end
