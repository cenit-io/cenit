module Setup
  Pin.class_eval do
    include RailsAdmin::Models::Setup::PinAdmin
  end
end
