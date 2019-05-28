module Setup
  Oauth2Authorization.class_eval do
    include RailsAdmin::Models::Setup::Oauth2AuthorizationAdmin
  end
end
