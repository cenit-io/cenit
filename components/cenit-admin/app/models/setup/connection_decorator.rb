module Setup
  Connection.class_eval do
    include RailsAdmin::Models::Setup::ConnectionAdmin
  end
end
