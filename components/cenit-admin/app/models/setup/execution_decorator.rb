module Setup
  Execution.class_eval do
    include RailsAdmin::Models::Setup::ExecutionAdmin
  end
end
