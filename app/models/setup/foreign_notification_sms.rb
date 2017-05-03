module Setup
  class ForeignNotificationSms < Setup::ForeignNotification
    include RailsAdmin::Models::Setup::ForeignNotificationSmsAdmin

    field :to, type: String
    field :body, type: String

    belongs_to :data_type, :class_name => Setup::DataType.name, :inverse_of => :sms_notifications

    allow :copy, :new, :edit, :export, :import

    # Send notification via sms message
    def send_message(data)
      v_to = render(data, to)
      v_body = render(data, body)
      # TODO: Send notification via sms message
    end
  end
end
