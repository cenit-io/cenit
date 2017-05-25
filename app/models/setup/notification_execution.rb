module Setup
  class NotificationExecution < Setup::Task
    include RailsAdmin::Models::Setup::NotificationExecutionAdmin

    agent_field :notification

    build_in_data_type

    belongs_to :notification, class_name: Setup::Notification.name, inverse_of: nil

    before_save do
      self.notification = Setup::Notification.where(id: message[:notification_id]).first
    end

    def run(message)
      notification_id = message.delete(:notification_id)
      notification = Setup::Notification.where(id: notification_id).first

      fail "Notification with id #{notification_id} not found" unless notification

      notification.send_message(message[:data])
    end

  end
end
