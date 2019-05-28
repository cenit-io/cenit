module Setup
  ConnectionRole.class_eval do
    include RailsAdmin::Models::Setup::ConnectionRoleAdmin
  end
end
