class SessionsController < Devise::SessionsController

  prepend_before_action :inspect_auth_token

  before_action :allow_x_frame

  def new
    if (provider = params[:with])
      redirect_to "/app/#{::Cenit::OpenId.app_key}?with=#{provider}&redirect_uri=#{Cenit.homepage}#{session_path(resource_name)}"
    elsif (code = params[:code])
      if (user = ::Cenit::OpenId.get_user_by(code))
        resource = resource_class.find_or_create_by(email: user.email)
        resource.confirmed_at ||= Time.now
        unless resource.encrypted_password.present?
          resource.password = Devise.friendly_token
        end
        resource.given_name ||= user.given_name
        resource.family_name ||= user.family_name
        if resource.attributes['name'].blank? && user.name
          resource.name = user.name
        end
        unless resource.attributes['picture_url']
          resource.picture_url = user.picture_url
        end
        resource.save
        set_flash_message(:notice, :signed_in) if is_flashing_format?
        yield resource if block_given?
        state = JSON.parse(params[:state]) rescue {}
        if (return_to = state['return_to'])
          session["#{resource_name}_return_to"] = return_to
        end
        sign_in_and_redirect resource
      else
        flash[:error] = 'Invalid authentication code'
        super
      end
    elsif @auth_token_user
      sign_in_and_redirect @auth_token_user
    else
      if params[:return_to]
        resource = resource_class.new(sign_in_params)
        store_location_for(resource, params[:return_to])
      end
      super
    end
  end

  def require_no_authentication
    r = super
    flash.delete(:alert) if @auth_token_user
    r
  end

  protected

  def allow_x_frame
    response.headers.delete('X-Frame-Options')
  end

  def inspect_auth_token
    if (token = params[:token]) &&
       (token = ::Cenit::AuthToken.where(token: token).first) &&
       (data = token.data).is_a?(Hash) &&
       (@auth_token_user = ::User.where(email: (email = data['email'])).first)
      sign_in(@auth_token_user)
      ::TourTrack.where(user_email: email).delete_all
    end
    true
  end
end