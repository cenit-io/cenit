module Setup
  module ForeignNotifications
    class Sms < Setup::ForeignNotification
      include RailsAdmin::Models::Setup::ForeignNotification::SmsNotificationAdmin
    end
  end
end
