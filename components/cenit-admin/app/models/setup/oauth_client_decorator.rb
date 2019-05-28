module Setup
  OauthClient.class_eval do
    include RailsAdmin::Models::Setup::OauthClientAdmin
  end
end
