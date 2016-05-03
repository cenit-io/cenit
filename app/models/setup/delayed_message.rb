module Setup
  class DelayedMessage
    include CenitUnscoped

    Setup::Models.exclude_actions_for self, :all

    Setup::BuildInDataType.regist(self)

    field :message, type: String
    field :publish_at, type: DateTime
    field :unscheduled, type: Boolean

    belongs_to :scheduler, class_name: Setup::Scheduler.to_s, inverse_of: :delayed_messages

    validates_presence_of :message

    before_save do
      unless publish_at.present?
        n_time = (scheduler && scheduler.next_time)
        self.unscheduled = true if n_time == -1
        self.publish_at = n_time || Time.now + (Cenit.default_delay || Cenit.scheduler_lookup_interval || 0)
      end
      end
    end
  end
