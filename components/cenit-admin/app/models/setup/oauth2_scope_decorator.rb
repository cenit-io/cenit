module Setup
  Oauth2Scope.class_eval do
    include RailsAdmin::Models::Setup::Oauth2ScopeAdmin
  end
end
