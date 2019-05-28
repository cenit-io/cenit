module Setup
  Action.class_eval do
    include RailsAdmin::Models::Setup::ActionAdmin
  end
end
