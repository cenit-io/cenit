module Setup
  RemoteOauthClient.class_eval do
    include RailsAdmin::Models::Setup::RemoteOauthClientAdmin
  end
end
