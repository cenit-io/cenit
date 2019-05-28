module Setup
  Push.class_eval do
    include RailsAdmin::Models::Setup::PushAdmin
  end
end
