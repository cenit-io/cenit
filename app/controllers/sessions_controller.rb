class SessionsController < Devise::SessionsController
  before_action :allow_x_frame

  def new
    if (provider = params[:with])
      state =
        if (user_options = resource_params)
          user_options
        else
          {}
        end.to_json
      client = OAuth2::Client.new(ENV['OPEN_ID_CLIENT_ID'], ENV['OPEN_ID_CLIENT_SECRET'], authorize_url: ENV['OPEN_ID_AUTH_URL'])
      redirect_to client.auth_code.authorize_url(scope: 'openid',
        redirect_uri: ENV['OPEN_ID_REDIRECT_URI'],
        state: state,
        with: provider)
    elsif (code = params[:code])
      client = OAuth2::Client.new(ENV['OPEN_ID_CLIENT_ID'], ENV['OPEN_ID_CLIENT_SECRET'], token_url: ENV['OPEN_ID_TOKEN_URL'])
      token = nil
      begin
        token = client.auth_code.get_token(code, redirect_uri: ENV['OPEN_ID_REDIRECT_URI'])
      rescue Exception => ex
        flash[:error] = ex.message
      end
      id_token = nil
      if token && (id_token = token.params['id_token']) &&
        (id_token = JWT.decode(id_token, nil, false, verfify_expiration: false)[0]) &&
        id_token['email'].present? && id_token['email_verified']
        resource = resource_class.find_or_create_by(email: id_token['email'])
        resource.confirmed_at = Time.now
        resource.password = pwd = Devise.friendly_token
        resource.password_confirmation= pwd
        resource.save
        set_flash_message(:notice, :signed_in) if is_flashing_format?
        yield resource if block_given?
        state = JSON.parse(params[:state]) rescue {}
        if (return_to = state['return_to'])
          session["#{resource_name}_return_to"] = return_to
        end
        sign_in_and_redirect resource
      else
        if id_token
          flash[:error] = 'It seems that your account at the selected provider is not confirmed so it can not be used for authentication'
        end
        super
      end
    else
      if params[:return_to]
        resource = resource_class.new(sign_in_params)
        store_location_for(resource, params[:return_to])
      end
      super
    end
  end

  protected

  def allow_x_frame
    response.headers.delete('X-Frame-Options')
  end
end