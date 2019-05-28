module Setup
  OauthProvider.class_eval do
    include RailsAdmin::Models::Setup::OauthProviderAdmin
  end
end
