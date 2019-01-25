module Setup
  class NotificationExecution < Setup::Task
    include ::RailsAdmin::Models::Setup::NotificationExecutionAdmin

    agent_field :notification

    build_in_data_type

    belongs_to :notification, class_name: Setup::Notification.name, inverse_of: nil

    before_save do
      self.notification = Setup::Notification.where(id: message[:notification_id]).first
    end

    def run(message)
      notification_id = message[:notification_id]
      notification = Setup::Notification.where(id: notification_id).first

      fail "Notification with ID #{notification_id} not found" unless notification

      record = notification.data_type.where(id: message[:record_id]).first

      fail "#{notification.data_type.custom_title} record with ID #{message[:record_id]} not found" unless record

      notification.process(record)
    end

  end
end
