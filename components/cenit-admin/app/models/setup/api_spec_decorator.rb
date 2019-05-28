module Setup
  ApiSpec.class_eval do
    include RailsAdmin::Models::Setup::ApiSpecAdmin
  end
end
