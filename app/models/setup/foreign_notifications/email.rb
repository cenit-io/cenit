module Setup
  module ForeignNotifications
    class Email < Setup::ForeignNotification
      include RailsAdmin::Models::Setup::ForeignNotification::EmailNotificationAdmin
    end
  end
end
