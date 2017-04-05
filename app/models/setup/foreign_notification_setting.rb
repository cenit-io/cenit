module Setup
  class ForeignNotificationSetting
    include CenitScoped
    include RailsAdmin::Models::Setup::ForeignNotificationSettingAdmin

    embedded_in :foreign_notification, :class_name => Setup::ForeignNotification.name, :inverse_of => :setting

    # Email setting vars
    field :send_email, type: Boolean
    field :email_to, type: String
    field :email_subject, type: String
    field :email_body, type: String

    # Http setting vars
    field :send_http_request, type: Boolean
    field :http_uri, type: String
    field :http_method, type: Symbol, :default => :GET
    field :http_params, type: Symbol, :default => :record_id

    # SMS setting vars
    field :send_sms, type: Boolean
    field :sms_to, type: String
    field :sms_body, type: String

    def http_method_enum
      [:GET, :POST, :PUSH, :DELETE]
    end

    def http_params_enum
      {
        'Send only record ID' => :record_id,
        'Send full record data' => :record_data,
      }
    end

    def label
      l = []
      l << 'E-Mail' if send_email
      l << 'HTTP' if send_http_request
      l << 'SMS' if send_sms
      l.empty? ? 'NONE' : l.join(', ')
    end
  end
end
