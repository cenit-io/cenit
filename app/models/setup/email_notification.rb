module Setup
  class EmailNotification < Setup::Notification
    include RailsAdmin::Models::Setup::EmailNotificationAdmin

    transformation_types Setup::Renderer, Setup::Converter
  end
end
