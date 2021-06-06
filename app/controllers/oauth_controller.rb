class OauthController < ApplicationController

  before_action { warden.authenticate! scope: :user if check_params }

  def index
    skip_consent = false
    if request.get?
      if @errors.blank?
        if @app_id && (@app_id.tenant == Account.current || @app_id.registered?)
          @token = Cenit::Token.create(data: { scope: @scope.to_s, redirect_uri: @redirect_uri, state: params[:state] }).token
          access_grant = Cenit::OauthAccessGrant.where(application_id: @app_id).first
          skip_consent =
            if access_grant
              @grant_scope = access_grant.oauth_scope
              @scope = @scope.diff(@grant_scope)
              @already_authorized = @grant_scope > @scope
            else
              false
            end
          skip_consent &&= !params[:show_consent].to_b
          @consent_action = :allow if skip_consent
        else
          @errors << 'Unregistered app'
        end
      end
    end
    if request.post? || skip_consent
      if (token = Cenit::Token.where(token: @token).first) &&
         token.data.is_a?(Hash) &&
         (redirect_uri = URI.parse(token.data['redirect_uri'])) &&
         (scope = token.data['scope'])
        token.destroy
        params = {}
        if (state = token.data['state'])
          params[:state] = state
        end
        if @consent_action == :allow
          code_token = Cenit::OauthCodeToken.create(scope: scope, user_id: User.current.id)
          params[:code] = code_token.token
        else
          params[:error] = 'Access denied'
        end
        redirect_uri.query = redirect_uri.query.to_s + params.to_param
        redirect_to redirect_uri.to_s
      else
        @errors << 'Consent time out'
      end
    end
    render :bad_request, status: :bad_request if @errors.present?
  end

  def token
    response = {}
    response_code = :bad_request
    errors = ''
    token_class =
      case (grant_type = params[:grant_type])
      when 'authorization_code'
        errors += 'Code missing. ' unless (auth_value = params[:code])
        Cenit::OauthCodeToken
      when 'refresh_token'
        errors += 'Refresh token missing. ' unless (auth_value = params[:refresh_token])
        Cenit::OauthRefreshToken
      else
        errors += 'Invalid grant_type parameter.'
        nil
      end
    if errors.blank? && (token = token_class.where(token: auth_value).first)
      token.set_current_tenant!
      token.destroy unless token.long_term?
      if (app_id = Cenit::ApplicationId.where(identifier: params[:client_id]).first) &&
         app_id.app.secret_token == params[:client_secret]
        if grant_type == 'authorization_code'
          errors += 'Invalid redirect_uri. ' unless app_id.nil? || app_id.redirect_uris.include?(params[:redirect_uri])
        end
      else
        errors += 'Invalid client credentials. '
      end
      begin
        response = Cenit::OauthAccessToken.for(app_id, token.scope, token.user_id, token.tenant)
        response_code = :ok
      rescue Exception => ex
        errors += ex.message
      end if errors.blank?
    else
      errors += "Invalid #{grant_type.gsub('_', ' ')}." if token_class
    end
    response = { error: errors } if errors.present?
    headers['Access-Control-Allow-Origin'] = request.headers['Origin'] || ::Cenit.homepage
    render json: response, status: response_code
  end

  def callback
    redirect_uri = authorization_show_path(id: :invalid_state_data)
    error = params[:error]
    if (cenit_token = CallbackAuthorizationToken.where(token: params[:state] || session[:oauth_state]).first) &&
       (User.current = cenit_token.set_current_tenant!.owner) && (auth = cenit_token.authorization)
      if User.current.has_role?(:super_admin)
        User.current.super_admin_enabled = true
      end
      begin
        auth.metadata[:redirect_token] = redirect_token = Devise.friendly_token
        redirect_uri =
          if (app = cenit_token.app_id) && (app = app.app)
            callback_authorization_id = auth.metadata[:callback_authorization_id] ||
                                        auth.metadata['callback_authorization_id'] ||
                                        auth.id
            callback_params = auth.metadata[:callback_authorization_params] ||
                              auth.metadata['callback_authorization_params']
            unless callback_params.is_a?(Hash)
              callback_params = {}
            end
            callback_params[:redirect_token] = redirect_token
            if app.is_a?(::Setup::Application) && app.authentication_method == :user_credentials
              callback_params[:'X-User-Access-Key'] = Tenant.current.owner.number
              callback_params[:'X-User-Access-Token'] = Tenant.current.owner.token
            end
            "/app/#{app.slug_id}/authorization/#{callback_authorization_id}?" + callback_params.to_param
          elsif (token_data = cenit_token.data).is_a?(Hash) && token_data.key?('redirect_uri')
            token_data['redirect_uri']
          else
            # TODO redirect_token is not useful here
            authorization_show_path(id: auth.id.to_s) + "?redirect_token=#{redirect_token}"
          end
        resolve_params = params.reject { |k, _| %w(controller action).include?(k) }
        if auth.accept_callback?(resolve_params)
          resolve_params[:cenit_token] = cenit_token
          auth.resolve!(resolve_params)
        else
          auth.cancel!
        end
      rescue Exception => ex
        json_params =
          begin
            params.to_json
          rescue
            params.to_s
          end
        report = Setup::SystemReport.create_from(ex, "Error on OAuth Callback controller with params: #{json_params}")
        error = "An unexpected error occurs (#{ex.message}). Ask for support by supplying this code: #{report.id}"
      end
    else
      error = 'Invalid state data'
    end

    cenit_token.delete if cenit_token

    if error.present?
      error = error[1..500] + '...' if error.length > 500
      flash[:error] = error.html_safe
      uri =
        begin
          URI.parse(redirect_uri)
        rescue
          nil
        end
      if uri && !uri.relative?
        uri.query = [uri.query, "error=#{error}"].compact.join('&')
        redirect_uri = uri.to_s
      end
    end

    redirect_to redirect_uri
  end

  def check_params
    @errors = []
    send("check_#{@_action_name}")
  end

  def check_index
    if request.get?
      @errors << 'Missing client_id.' unless (@client_id = params[:client_id])
      if (@response_type = params[:response_type])
        @errors << 'Invalid response_type.' unless @response_type == 'code'
      else
        @errors << 'Missing response_type.'
      end
      @errors << 'Missing redirect_uri.' unless (@redirect_uri = params[:redirect_uri])
      @errors << 'Missing scope.' unless (@scope = params[:scope])
      if (@app_id = Cenit::ApplicationId.where(identifier: @client_id).first)
        unless @app_id.redirect_uris.include?(@redirect_uri)
          @errors << 'Invalid redirect_uri'
        end
      else
        @errors << 'Invalid credentials'
      end if @errors.blank?
      if @scope.is_a?(String)
        @scope = Cenit::OauthScope.new(@scope)
      end
      @errors << 'Invalid scope' unless @scope.nil? || @scope.valid?
    else
      @errors << 'Consent time out' unless (@token = params[:token])
      @consent_action = params[:allow] ? :allow : :deny
    end
    true
  end

  def check_callback
    false
  end

  def check_token
    false
  end

  protected :check_params, :check_index, :check_callback, :check_token
end
