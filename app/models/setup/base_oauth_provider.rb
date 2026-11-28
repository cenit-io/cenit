module Setup
  class BaseOauthProvider < AuthorizationProvider

    abstract_class true

    def self.response_type_enum
      ['code']
    end

    def self.token_method_enum
      %w(POST GET)
    end

    def self.refresh_token_strategy_enum
      [
        'Google v4',
        'custom',
        'default',
        'none'
      ]
    end

    build_in_data_type
      .referenced_by(:namespace, :name)
      .and_polymorphic(properties: {
        response_type: {
          enum: response_type_enum
        },
        token_method: {
          enum: token_method_enum
        },
        refresh_token_strategy: {
          enum: refresh_token_strategy_enum
        }
      })

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
      abort_if_has_errors
    end

    def response_type_enum
      self.class.response_type_enum
    end

    def token_method_enum
      self.class.token_method_enum
    end

    def refresh_token_strategy_enum
      self.class.refresh_token_strategy_enum
    end

    def refresh_token(authorization)
      strategy = refresh_token_strategy
      unless refresh_token_strategy_enum.include?(strategy)
        raise ArgumentError, 'Unsupported OAuth refresh strategy; configure a supported provider and authorize again'
      end

      if authorization.authorized?
        public_send(strategy.tr(' ', '_').underscore + '_refresh_token', authorization)
        authorization.access_token
      else
        fail "#{authorization.custom_title} not yet authorized"
      end
    end

    def is_time_to_refresh?(authorization, refresh_delay = Cenit.delay_time_for_token_refresh.seconds)
      authorization.authorized_at.nil? || (
        (authorization.authorized_at + authorization.token_span.to_i.seconds - refresh_delay) < Time.now
      )
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
      if (refresh_token = authorization.refresh_token) && is_time_to_refresh?(authorization)
        fail 'Missing client configuration' unless (client = authorization.client)
        http_response = HTTMultiParty.post(
          authorization.token_endpoint,
          headers: {
            'Content-Type' => 'application/x-www-form-urlencoded'
          }.merge(client.conformed_request_token_headers(template_parameters = authorization.template_parameters_hash)),
          query: client.conformed_request_token_parameters(template_parameters),
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
      if (refresh_token = authorization.refresh_token) && is_time_to_refresh?(authorization)
        fail 'Missing client configuration' unless authorization.client
        post = Setup::Connection.post('https://www.googleapis.com/oauth2/v4/token')
        http_response = post.submit(
          headers: { 'Content-Type' => 'application/x-www-form-urlencoded' },
          body: {
            grant_type: :refresh_token,
            refresh_token: refresh_token,
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

    def client(name)
      Setup::OauthClient.where(provider_id: id, name: name).first
    end
  end
end
