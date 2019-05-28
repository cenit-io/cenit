module Setup
  Operation.class_eval do
    include RailsAdmin::Models::Setup::OperationAdmin
  end
end
