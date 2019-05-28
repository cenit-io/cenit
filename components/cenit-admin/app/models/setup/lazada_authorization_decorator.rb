module Setup
  LazadaAuthorization.class_eval do
    include RailsAdmin::Models::Setup::LazadaAuthorizationAdmin
  end
end
