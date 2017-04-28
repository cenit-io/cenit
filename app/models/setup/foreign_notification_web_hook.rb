module Setup
  class ForeignNotificationWebHook < Setup::ForeignNotification
    include RailsAdmin::Models::Setup::ForeignNotification::WebHookNotificationAdmin
  end
end
