module Setup
  Authorization.class_eval do
    include RailsAdmin::Models::Setup::AuthorizationAdmin
  end
end
