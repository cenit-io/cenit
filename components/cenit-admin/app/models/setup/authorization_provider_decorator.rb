module Setup
  AuthorizationProvider.class_eval do
    include RailsAdmin::Models::Setup::AuthorizationProviderAdmin
  end
end
