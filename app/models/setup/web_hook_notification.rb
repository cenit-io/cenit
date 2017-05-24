require 'rest-client'

module Setup
  class WebHookNotification < Setup::Notification
    include RailsAdmin::Models::Setup::WebHookNotificationAdmin

    field :uri, type: String
    field :method, type: Symbol, :default => :GET
    field :params, type: Symbol, :default => :record_id
    field :params_as_json, type: Boolean, :default => false

    belongs_to :data_type, :class_name => Setup::DataType.name, inverse_of: nil

    allow :copy, :new, :edit, :export, :import

    def method_enum
      [:GET, :POST, :PUSH, :DELETE]
    end

    def params_enum
      {
        'No parameters' => :without_parameters,
        'Send only record ID' => :record_id,
        'Send all record data' => :record_data,
        'Send full event data' => :event_data
      }
    end

    # Send notification via http request
    def send_message(data)
      v_uri = render(data, uri)
      v_data = case params
               when :record_id
                 { id: data[:record][:id] }
               when :record_data
                 data[:record]
               when :event_data
                 data
               else
                 {}
               end

      v_data = params_as_json ? { data: v_data.to_json } : v_data

      response = RestClient::Request.execute(
        :url => v_uri,
        :method => method,
        :headers => {
          'Content-Type' => 'application/json',
          'params' => v_data
        }
      )
      # TODO: Check response status and create system notification.
    end
  end
end
