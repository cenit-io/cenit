module Setup
  Task.class_eval do
    include RailsAdmin::Models::Setup::TaskAdmin
  end
end
