module Setup
  Event.class_eval do
    include RailsAdmin::Models::Setup::EventAdmin
  end
end
