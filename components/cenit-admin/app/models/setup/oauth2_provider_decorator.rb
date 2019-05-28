module Setup
  Oauth2Provider.class_eval do
    include RailsAdmin::Models::Setup::Oauth2ProviderAdmin
  end
end
