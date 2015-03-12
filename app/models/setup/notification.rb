module Setup
  class Notification
    include CenitScoped

    Setup::Models.exclude_actions_for self, :new

    belongs_to :flow, :class_name => Setup::Flow.to_s, inverse_of: nil

    field :http_status_code, type: String
    field :http_status_message, type: String
    field :count, type: Integer
    field :json_data, type: String

    def must_be_resend?
      !(200...299).include?(http_status_code)
    end

    def resend
      return unless self.must_be_resend?
      self.flow.process_json_data(self.json_data, self.id)
    end

  end
end
