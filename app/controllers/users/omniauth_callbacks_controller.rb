class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def doorkeeper
    puts " ^^^^^^^^^^^^^^^ llego hasta aqui   "
    oauth_data = request.env["omniauth.auth"]
    puts " ^^^^^^^^^^^^^^^ oauth_data #{oauth_data.inspect}  "
    @user = User.find_or_create_for_doorkeeper_oauth(oauth_data)
    @user.update_doorkeeper_credentials(oauth_data)
    @user.save

    sign_in_and_redirect @user
  end
end
