module Setup
  EmailFlow.class_eval do
    include RailsAdmin::Models::Setup::EmailFlowAdmin
  end
end
