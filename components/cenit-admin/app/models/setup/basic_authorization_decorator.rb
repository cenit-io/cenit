module Setup
  BasicAuthorization.class_eval do
    include RailsAdmin::Models::Setup::BasicAuthorizationAdmin
  end
end
