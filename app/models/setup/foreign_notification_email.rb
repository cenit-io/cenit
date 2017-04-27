module Setup
  class ForeignNotificationEmail < Setup::ForeignNotification
    include RailsAdmin::Models::Setup::ForeignNotification::EmailNotificationAdmin
  end
end
