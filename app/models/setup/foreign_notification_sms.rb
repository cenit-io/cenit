module Setup
  class ForeignNotificationSms < Setup::ForeignNotification
    include RailsAdmin::Models::Setup::ForeignNotification::SmsNotificationAdmin
  end
end
