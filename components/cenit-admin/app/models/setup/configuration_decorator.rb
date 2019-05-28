module Setup
  Configuration.class_eval do
    include RailsAdmin::Models::Setup::ConfigurationAdmin
  end
end
