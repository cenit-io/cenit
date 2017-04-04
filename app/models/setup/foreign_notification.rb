module Setup
  class ForeignNotification
    include CenitScoped
    include RailsAdmin::Models::Setup::ForeignNotificationAdmin

    field :type, type: Symbol
    field :active, type: Boolean
    field :setting, type: Object

    has_and_belongs_to_many :observers, :class_name => Setup::Observer.name, :inverse_of => :foreign_notifications
    belongs_to :data_type, :class_name => Setup::DataType.name, :inverse_of => :foreign_notifications

    def type_enum
      {
        'E-Mail' => :email,
        'HTTP' => :http,
        'SMS' => :sms
      }
    end

    def label
      "#{type_enum.invert[type]}"
    end

    def send_message
      send("send_#{type.to_s}_message")
    end

    protected

    def send_email_message
      # TODO: Send notification via email message
    end

    def send_http_message
    # TODO: Send notification via http message
    end

    def send_sms_message
      # TODO: Send notification via sms message
    end
  end
end
