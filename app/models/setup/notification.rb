module Setup
  class Notification
    include CenitScoped

    Setup::Models.exclude_actions_for self, :new, :edit, :update

    belongs_to :flow, class_name: Setup::Flow.to_s, inverse_of: nil

    field :response, type: Hash
    field :retries, type: Integer, default: 0
    field :message, type: String
    field :exception_message, type: String

    def can_retry?
      response.blank? || !(200...299).include?(response['code'])
    end

    def retry
      flow.process(JSON.parse(message).merge(notification_id: id.to_s)) if can_retry?
    end

  end
end
