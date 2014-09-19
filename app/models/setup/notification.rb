module Setup
  class Notification
    include Mongoid::Document
    include Mongoid::Timestamps

    field :webhook, type: String
    field :message, type: String
    field :http_status_code, type: String
    field :http_status_message, type: String
    field :count, type: Integer

    belongs_to :connection_id, :class_name => "Setup::Connection"

    def must_be_resended?
      !(200...299).include?(http_status_code)
    end

    def resend
      return unless self.must_be_resended?
      message = {
        :body => self.message,
        :connection_id => self.connection_id,
        :webhook => self.webhook,
        :notification_id => self.id
      }
      Cenit::Rabbit.send_to_rabbitmq(message)
    end

  end
end
