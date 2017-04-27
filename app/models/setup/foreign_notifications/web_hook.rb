module Setup
  module ForeignNotifications
    class WebHook < Setup::ForeignNotification
      include RailsAdmin::Models::Setup::ForeignNotification::WebHookNotificationAdmin
    end
  end
end
