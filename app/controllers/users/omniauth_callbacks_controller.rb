class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  protect_from_forgery with: :null_session

  def doorkeeper
    oauth_data = request.env["omniauth.auth"]
    @user = User.find_or_initialize_for_doorkeeper_oauth(oauth_data)
    @user.update_doorkeeper_credentials(oauth_data)
    @user.save

    if @user.persisted?
      # current_user = @user
      state = JSON.parse(params[:state]) rescue {}
      if (redirect_path = state['redirect_path'])
        sign_in @user, :event => :authentication
        if (msg = state['flash_message'])
          flash[:info] = msg
        end
        redirect_to redirect_path
      else
        sign_in_and_redirect @user, :event => :authentication #this will throw if @user is not activated
        set_flash_message(:notice, :success, :kind => "Doorkeeper") if is_navigational_format?
      end
    else
      session["devise.doorkeeper_data"] = request.env["omniauth.auth"]
      redirect_to new_user_registration_url
    end
  end
end
