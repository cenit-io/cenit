module Setup
  Scheduler.class_eval do
    include RailsAdmin::Models::Setup::SchedulerAdmin
  end
end
