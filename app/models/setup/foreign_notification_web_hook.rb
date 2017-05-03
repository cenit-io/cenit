module Setup
  class ForeignNotificationWebHook < Setup::ForeignNotification
    include RailsAdmin::Models::Setup::ForeignNotificationWebHookAdmin

    field :uri, type: String
    field :method, type: Symbol, :default => :GET
    field :params, type: Symbol, :default => :record_id

    belongs_to :data_type, :class_name => Setup::DataType.name, :inverse_of => :web_hook_notifications

    def http_method_enum
      [:GET, :POST, :PUSH, :DELETE]
    end

    def http_params_enum
      {
        'Send only record ID' => :record_id,
        'Send full record data' => :record_data,
      }
    end

    # Send notification via http request
    def send_message(data)
      v_uri = render(data, uri)
      v_data = (params == :record_id) ? { id: data[:data][:id] } : data[:data]
      # TODO: Send notification via http message
    end
  end
end
