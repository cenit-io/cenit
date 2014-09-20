module Setup
  class Notification
    include Mongoid::Document
    include Mongoid::Timestamps

    belongs_to :flow_id, :class_name => "Setup::Flow"

    field :http_status_code, type: String
    field :http_status_message, type: String
    field :count, type: Integer
    field :object_id, type: String

    def must_be_resended?
      !(200...299).include?(http_status_code)
    end

    def resend
      return unless self.must_be_resended?
      object = self.flow.data_type.model.constantize.find(self.object_id)
      self.flow.process(object)
    end

  end
end
