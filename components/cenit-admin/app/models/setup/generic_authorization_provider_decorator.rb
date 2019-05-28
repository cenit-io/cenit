module Setup
  GenericAuthorizationProvider.class_eval do
    include RailsAdmin::Models::Setup::GenericAuthorizationProviderAdmin
  end
end
