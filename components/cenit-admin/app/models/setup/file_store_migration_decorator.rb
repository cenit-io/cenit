module Setup
  FileStoreMigration.class_eval do
    include RailsAdmin::Models::Setup::FileStoreMigrationAdmin
  end
end
