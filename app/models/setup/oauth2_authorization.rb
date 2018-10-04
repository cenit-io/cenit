module Setup
  class Oauth2Authorization < Setup::BaseOauthAuthorization
    include CenitScoped
    include RailsAdmin::Models::Setup::Oauth2AuthorizationAdmin

    build_in_data_type.with(:namespace, :name, :provider, :client, :parameters, :template_parameters, :scopes)
    build_in_data_type.referenced_by(:namespace, :name)

    has_and_belongs_to_many :scopes, class_name: Setup::Oauth2Scope.to_s, inverse_of: nil

    field :token_type, type: String
    field :refresh_token, type: String
    field :id_token, type: String

    auth_template_parameters access_token: ->(oauth2_auth) { oauth2_auth.fresh_access_token }

    def check
      if super
        errors.add(:client, 'provider is not OAuth 2.0 compatible') unless provider.is_a?(Setup::Oauth2Provider)
        scopes.each do |scope|
          next if scope.provider == provider
          errors.add(:scopes, "contains not compatible scope #{scope.name} of #{scope.provider.custom_title}")
        end
      end
      errors.blank?
    end

    def cancel
      self.id_token = nil
      super
    end

    def ready_to_save?
      client.present?
    end

    def build_auth_header(template_parameters)
      ((token_type.to_s.capitalize || 'OAuth').to_s + ' ' + fresh_access_token.to_s).strip #TODO For Facebook that do not use token type
    end

    def callback_key
      :redirect_uri
    end

    def create_http_client(options = {})
      http_client = HttpClient.new(client.get_identifier, client.get_secret, options)
      if (http_proxy = Cenit.http_proxy)
        http_client.connection.proxy(http_proxy)
      end
      http_client
    end

    def authorize_url(params)
      if (cenit_token = params.delete(:cenit_token)) && !params.has_key?(:state)
        params[:state] = cenit_token.token
      end
      create_http_client(authorize_url: authorization_endpoint).auth_code.authorize_url(authorize_params(params))
    end

    def authorize_params(params)
      scope_sep = provider.scope_separator.blank? ? ' ' : provider.scope_separator
      params[:scope] ||= conformed_scopes.values.to_a.join(scope_sep)
      super(params)
    end

    def request_token(params)
      http_client = create_http_client(token_url: token_endpoint, token_method: token_method.to_s.downcase.to_sym)
      token = http_client.get_token_with(:auth_code, params[:code]) do |parameters, headers|
        parameters.merge!(token_params(parameters, params)) if parameters
        headers.merge!(token_headers(headers, params)) if headers
      end
      self.token_type = token.params['token_type']
      self.authorized_at =
        if (time = token.params['created_at'])
          time.is_a?(String) ? Time.parse(time) : Time.at(time.to_i)
        else
          Time.now
        end
      self.access_token = token.token
      self.token_span = token.expires_in || token.params['token_span']
      self.refresh_token = token.refresh_token if token.refresh_token
      self.id_token = token.params['id_token']
    end

    def accept_callback?(params)
      params[:code].present?
    end

    class HttpClient < OAuth2::Client

      def thread_id(suffix)
        "#{self.class}##{object_id}:#{suffix}"
      end

      def get_token_with(*args, &block)
        if block
          Thread.current[thread_id(:get_token_proc)] = block
        end
        strategy = args.shift
        token = send(strategy).get_token(*args)
        Thread.current[thread_id(:get_token_proc)] = nil
        token
      end

      def get_token(params, access_token_opts = {}, access_token_class = OAuth2::AccessToken)
        if (proc = Thread.current[thread_id(:get_token_proc)])
          proc.call(params, headers = params[:headers])
          params[:headers] = headers if headers
        end
        super
      end
    end
  end
end
