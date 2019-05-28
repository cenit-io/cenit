module Setup
  BaseOauthProvider.class_eval do
    include RailsAdmin::Models::Setup::BaseOauthProviderAdmin
  end
end
