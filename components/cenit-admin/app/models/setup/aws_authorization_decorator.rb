module Setup
  AwsAuthorization.class_eval do
    include RailsAdmin::Models::Setup::AwsAuthorizationAdmin
  end
end
