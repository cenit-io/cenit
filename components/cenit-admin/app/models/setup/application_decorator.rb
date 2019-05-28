module Setup
  Application.class_eval do
    include RailsAdmin::Models::Setup::ApplicationAdmin
  end
end
