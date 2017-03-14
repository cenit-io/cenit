module Setup
  class DelayedMessage
    include CenitUnscoped
    include RailsAdmin::Models::Setup::DelayedMessageAdmin

    deny :all

    build_in_data_type

    field :message, type: String
    field :publish_at, type: DateTime
    field :unscheduled, type: Boolean

    belongs_to :scheduler, class_name: Setup::Scheduler.to_s, inverse_of: :delayed_messages

    validates_presence_of :message

    before_save do
      unless publish_at.present?
        self.publish_at =
          if (n_time = (scheduler && scheduler.next_time))
            n_time
          else
            if scheduler
              nil
            else
              Time.now + (Cenit.default_delay || Cenit.scheduler_lookup_interval || 0)
            end
          end
      end
      publish_at.present?
    end
    
  end
end
