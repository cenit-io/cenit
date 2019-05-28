module Setup
  AuthorizationClient.class_eval do
    include RailsAdmin::Models::Setup::AuthorizationClientAdmin
  end
end
