module Setup
  Updater.class_eval do
    include RailsAdmin::Models::Setup::UpdaterAdmin
  end
end
