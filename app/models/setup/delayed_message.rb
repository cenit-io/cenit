module Setup
  class DelayedMessage
    include CenitUnscoped

    Setup::Models.exclude_actions_for self, :all

    Setup::BuildInDataType.regist(self)

    field :message, type: String
    field :publish_at, type: DateTime

    belongs_to :scheduler, class_name: Setup::Scheduler.to_s, inverse_of: :delayed_messages

    validates_presence_of :message

    before_save do
      unless publish_at.present?
        self.publish_at = (scheduler && scheduler.next_time) || Time.now + (Cenit.default_delay || Cenit.scheduler_lookup_interval || 0)
      end
    end
  end
end
