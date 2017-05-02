module Setup
  class ForeignNotificationEmail < Setup::ForeignNotification
    include RailsAdmin::Models::Setup::ForeignNotification::EmailNotificationAdmin

    belongs_to :data_type, :class_name => Setup::DataType.name, :inverse_of => :email_notifications
  end
end
