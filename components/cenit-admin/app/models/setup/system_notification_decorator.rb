module Setup
  SystemNotification.class_eval do
    include RailsAdmin::Models::Setup::SystemNotificationAdmin
  end
end
