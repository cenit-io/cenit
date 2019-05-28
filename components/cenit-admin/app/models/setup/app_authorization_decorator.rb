module Setup
  AppAuthorization.class_eval do
    include RailsAdmin::Models::Setup::AppAuthorizationAdmin
  end
end
