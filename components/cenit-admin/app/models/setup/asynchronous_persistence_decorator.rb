module Setup
  AsynchronousPersistence.class_eval do
    include RailsAdmin::Models::Setup::AsynchronousPersistenceAdmin
  end
end
