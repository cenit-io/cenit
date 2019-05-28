module Setup
  RubyUpdater.class_eval do
    include RailsAdmin::Models::Setup::RubyUpdaterAdmin
  end
end
