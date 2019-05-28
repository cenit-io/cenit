module Setup
  OauthAuthorization.class_eval do
    include RailsAdmin::Models::Setup::OauthAuthorizationAdmin
  end
end
