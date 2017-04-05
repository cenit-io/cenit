module Setup
  class ForeignNotification
    include CenitScoped
    include RailsAdmin::Models::Setup::ForeignNotificationAdmin

    field :active, type: Boolean

    has_and_belongs_to_many :observers, :class_name => Setup::Observer.name, :inverse_of => :foreign_notifications
    belongs_to :data_type, :class_name => Setup::DataType.name, :inverse_of => :foreign_notifications

    embeds_one :setting, :class_name => Setup::ForeignNotificationSetting.name, :inverse_of => :foreign_notification
    accepts_nested_attributes_for :setting

    after_create :set_default_setting

    def label
      "n#{data_type.foreign_notifications.index(self)+1}"
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

    protected

    def set_default_setting
      if self.setting.nil?
        self.setting = ForeignNotificationSetting.new
        save
      end
    end
  end
end
