module Setup
  Notification.class_eval do
    include RailsAdmin::Models::Setup::NotificationAdmin
  end
end
