module Setup
  Observer.class_eval do
    include RailsAdmin::Models::Setup::ObserverAdmin
  end
end
