class OauthController < ApplicationController

  before_filter do
    if check_params
      warden.authenticate! scope: :user
    else
      render :bad_request if @errors.present?
    end
  end

  def index
    if request.get?
      if @app_id && (@app_id.tenant == Account.current || @app_id.registered?)
        @token = Cenit::Token.create(data: { scope: @scope.to_s, redirect_uri: @redirect_uri, state: params[:state] }).token
      else
        @errors << 'Unregistered app'
      end
    else
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
          params[:error] ='Access denied'
        end
        redirect_uri.query = redirect_uri.query.to_s + params.to_param
        redirect_to redirect_uri.to_s
      else
        @errors << 'Consent time out'
      end
    end
    render :bad_request if @errors.present?
  end

  def callback
    redirect_path = rails_admin.index_path(Setup::Authorization.to_s.underscore.gsub('/', '~'))
    error = params[:error]
    if (cenit_token = OauthAuthorizationToken.where(token: params[:state] || session[:oauth_state]).first) &&
      cenit_token.set_current_tenant! && (authorization = cenit_token.authorization)
      begin
        authorization.metadata[:redirect_token] = redirect_token = Devise.friendly_token
        redirect_path =
          if (app = cenit_token.application)
            "/app/#{app.identifier}/authorization/#{authorization.id}?redirect_token=#{redirect_token}" +
              case app.authentication_method
              when :user_credentials
                "X-User-Access-Key=#{Account.current.owner.number}&X-User-Access-Token=#{Account.current.owner.token}"
              else
                #:application_id
                ''
              end
          else
            rails_admin.show_path(model_name: authorization.class.to_s.underscore.gsub('/', '~'), id: authorization.id.to_s) + "?redirect_token=#{redirect_token}"
          end
        if authorization.accept_callback?(params)
          params[:cenit_token] = cenit_token
          authorization.request_token!(params)
        else
          authorization.cancel!
        end
      rescue Exception => ex
        error = ex.message
      end
    else
      error = 'Invalid state data'
    end

    cenit_token.delete if cenit_token

    if error.present?
      error = error[1..500] + '...' if error.length > 500
      flash[:error] = error.html_safe
    end

    redirect_to redirect_path
  end

  private

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
end
