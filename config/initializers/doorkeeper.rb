Doorkeeper.configure do
   orm :mongoid4

  resource_owner_authenticator do
    current_user || warden.authenticate!(:scope => :user)
  end

  resource_owner_from_credentials do |routes|
    u = User.find_for_database_authentication(:email => params[:username])
    u if u && u.valid_password?(params[:password])
  end
  
  skip_authorization do
    true
  end

   admin_authenticator do
     if(current_user)
       redirect_to(root_path) unless current_user.has_role?(:super_admin)
     else
       redirect_to(root_path)
     end
   end

  default_scopes  :public
  optional_scopes :write, :update, :userinfo

  access_token_methods :from_access_token_param, :from_bearer_param, :from_bearer_authorization
  grant_flows %w(authorization_code implicit password client_credentials)

end
