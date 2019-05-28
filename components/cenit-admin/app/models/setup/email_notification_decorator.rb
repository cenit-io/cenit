module Setup
  EmailNotification.class_eval do
    include RailsAdmin::Models::Setup::EmailNotificationAdmin
  end
end
