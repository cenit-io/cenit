class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  protect_from_forgery with: :null_session
  def doorkeeper
    oauth_data = request.env["omniauth.auth"]
    @user = User.find_or_create_for_doorkeeper_oauth(oauth_data)
    @user.update_doorkeeper_credentials(oauth_data)
    @user.save

    if @user.persisted?
       sign_in_and_redirect @user, :event => :authentication #this will throw if @user is not activated
       set_flash_message(:notice, :success, :kind => "Doorkeeper") if is_navigational_format?
    else
      session["devise.doorkeeper_data"] = request.env["omniauth.auth"]
      redirect_to new_user_registration_url
    end
  end
end
