# require 'handlebars'

module Setup
  class ForeignNotification
    include CenitScoped
    include RailsAdmin::Models::Setup::ForeignNotificationAdmin

    field :name, type: String
    field :active, type: Boolean

    has_and_belongs_to_many :observers, :class_name => Setup::Observer.name, :inverse_of => :foreign_notifications
    belongs_to :data_type, :class_name => Setup::DataType.name, :inverse_of => :foreign_notifications

    # Send notification via email, http or sms message.
    def send_message(data)
      send_email_message(data) if setting.send_email
      send_http_message(data) if setting.send_http_request
      send_sms_message(data) if setting.send_sms
    end

    protected

    # Render data in handlebars template.
    def render(data, template)
      handlebars = Handlebars::Context.new
      handlebars.compile(template).call(data)
    end

  end
end