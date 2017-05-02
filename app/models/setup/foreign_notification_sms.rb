module Setup
  class ForeignNotificationSms < Setup::ForeignNotification
    include RailsAdmin::Models::Setup::ForeignNotification::SmsNotificationAdmin

    belongs_to :data_type, :class_name => Setup::DataType.name, :inverse_of => :sms_notifications
  end
end
