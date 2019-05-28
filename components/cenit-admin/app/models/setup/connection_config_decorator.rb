module Setup
  ConnectionConfig.class_eval do
    include RailsAdmin::Models::Setup::ConnectionConfigAdmin
  end
end
