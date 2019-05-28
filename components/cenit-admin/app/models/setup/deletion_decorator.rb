module Setup
  Deletion.class_eval do
    include RailsAdmin::Models::Setup::DeletionAdmin
  end
end
