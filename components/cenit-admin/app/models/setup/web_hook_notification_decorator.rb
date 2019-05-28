module Setup
  WebHookNotification.class_eval do
    include RailsAdmin::Models::Setup::WebHookNotificationAdmin
  end
end
