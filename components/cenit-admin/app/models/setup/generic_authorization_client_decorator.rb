module Setup
  GenericAuthorizationClient.class_eval do
    include RailsAdmin::Models::Setup::GenericAuthorizationClientAdmin
  end
end
