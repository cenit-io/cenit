module Setup
  class ForeignNotificationWebHook < Setup::ForeignNotification
    include RailsAdmin::Models::Setup::ForeignNotification::WebHookNotificationAdmin

    belongs_to :data_type, :class_name => Setup::DataType.name, :inverse_of => :web_hook_notifications
  end
end
