module Setup
  class ForeignNotificationExecution < Setup::Task
    agent_field :foreign_notification

    build_in_data_type

    belongs_to :foreign_notification, class_name: Setup::ForeignNotification.name, inverse_of: nil

    before_save do
      self.foreign_notification = Setup::ForeignNotification.where(id: message[:foreign_notification_id]).first
    end

    def run(message)
      foreign_notification_id = message[:foreign_notification_id]
      foreign_notification = Setup::ForeignNotification.where(id: foreign_notification_id).first

      if foreign_notification
        foreign_notification.send_message()
      else
        fail "Foreign notification with id #{foreign_notification_id} not found"
      end
    end
    
  end
end
