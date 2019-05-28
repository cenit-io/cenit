module Setup
  GenericCallbackAuthorization.class_eval do
    include RailsAdmin::Models::Setup::GenericCallbackAuthorizationAdmin
  end
end
