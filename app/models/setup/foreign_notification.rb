require 'handlebars'

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
      "n#{data_type.foreign_notifications.index(self)+1}" if data_type
    end

    # Send notification via email, http or sms message.
    def send_message(data)
      send_email_message(data) if setting.send_email
      send_http_message(data) if setting.send_http_request
      send_sms_message(data) if setting.send_sms
    end

    protected

    # Send notification via email message
    def send_email_message(data)
      to = render(data, setting.email_to)
      subject = render(data, setting.email_subject)
      if (translator = setting.email_template)
        body = translator.run({ object_id: data[:record][:id], data: data })
      else
        body ||= render(data, setting.email_body)
      end
      ForeignNotificationMailer.send_email(to, subject, body, setting.smtp_provider.to_hash).deliver_now
    end

    # Send notification via http message
    def send_http_message(data)
      uri = render(data, setting.http_uri)
      data = setting.http_data == :record_id ? { id: data[:data][:id] } : data[:data]
      # TODO: Send notification via http message
    end

    # Send notification via sms message
    def send_sms_message(data)
      to = render(data, setting.sms_to)
      body = render(data, setting.sms_body)
      # TODO: Send notification via sms message
    end

    protected

    # Render data in handlebars template.
    def render(data, template)
      handlebars = Handlebars::Context.new
      handlebars.compile(template).call(data)
    end

    def set_default_setting
      if self.setting.nil?
        self.setting = ForeignNotificationSetting.new
        save
      end
    end
  end
end
