module Setup
  class NotificationFlowExecution < Setup::Task

    agent_field :notification, :notification_id

    build_in_data_type

    belongs_to :notification, class_name: Setup::NotificationFlow.name, inverse_of: nil

    def auto_description
      if (notification = agent_from_msg) && notification.data_type
        "Executing notification #{notification.custom_title} with #{notification.data_type.custom_title} ID: #{message[:record_id]}"
      else
        super
      end
    end

    def run(message)
      notification_id = message[:notification_id]
      notification = Setup::NotificationFlow.where(id: notification_id).first

      fail "Notification flow with ID #{notification_id} not found" unless notification

      record = notification.data_type.where(id: message[:record_id]).first

      fail "#{notification.data_type.custom_title} record with ID #{message[:record_id]} not found" unless record

      notification.process(record)
    end

  end
end
