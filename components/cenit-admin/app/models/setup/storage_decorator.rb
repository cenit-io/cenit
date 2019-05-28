module Setup
  Storage.class_eval do
    include RailsAdmin::Models::Setup::StorageAdmin
  end
end
