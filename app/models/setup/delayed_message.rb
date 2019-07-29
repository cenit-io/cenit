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
    belongs_to :tenant, class_name: Account.to_s, inverse_of: nil

    validates_presence_of :message

    before_save do
      self.tenant ||= Tenant.current
      unless publish_at.present?
        self.publish_at =
          if (n_time = (scheduler&.next_time))
            n_time
          else
            if scheduler
              nil
            else
              self.class.default_publish_at
            end
          end
      end
      publish_at.present?
    end

    after_save :send_to_adapter

    after_destroy :remove_from_adapter

    def send_to_adapter
      self.class.adapter.digest(self)
    end

    def remove_from_adapter
      self.class.adapter.remove(self)
    end

    module MongoidAdapter
      extend self

      def set_load_on_start(_flag = true)
        # Already done!
      end

      def load_on_start?
        false
      end

      def load_on_start
        # Already done!
      end

      def digest(_delayed_message)
        # Already done!
      end

      def remove(_delayed_message)
        # Already done!
      end

      def reschedule(delayed_message, publish_at)
        DelayedMessage.where(id: delayed_message[:id]).update_one(publish_at: publish_at)
      end

      def for_each_ready(opts = {}, &block)
        query = DelayedMessage.where(:publish_at.lte => Time.now)
        if (limit = opts[:limit])
          query = query.limit(limit)
        end
        query.each(&block) if block
      end
    end

    module RedisAdapter
      extend self

      SET_KEY = 'delayed_messages'
      DELAYED_MESSAGE_PREFIX = 'delayed_message#'
      LOAD_ON_START_KEY = 'delayed_message_load_on_start'

      def get(key)
        JSON.parse(Cenit::Redis.get(key)).with_indifferent_access
      rescue
        nil
      end

      def key_for(delayed_message)
        DELAYED_MESSAGE_PREFIX + delayed_message[:id].to_s
      end

      def delayed_message_id_from(key)
        key.match(/\A#{DELAYED_MESSAGE_PREFIX}(.*)/)[1]
      end

      def all_keys
        Cenit::Redis.keys("#{DELAYED_MESSAGE_PREFIX}*")
      end

      def set_load_on_start(flag = true)
        if flag
          Cenit::Redis.set(LOAD_ON_START_KEY, 'true')
        else
          Cenit::Redis.del(LOAD_ON_START_KEY)
        end
      end

      def load_on_start?
        Cenit::Redis.exists(LOAD_ON_START_KEY)
      end

      def load_on_start
        Cenit::Redis.del SET_KEY, *all_keys
        yield if Cenit::Redis.del(LOAD_ON_START_KEY) > 0 && block_given?
      end

      def digest(delayed_message)
        score = (delayed_message[:publish_at] || Time.now).to_i
        key = key_for(delayed_message)
        Cenit::Redis.pipelined do |redis|
          redis.set(key, hash_for(delayed_message).to_json)
          redis.zadd(SET_KEY, score, key)
        end
      end

      def remove(delayed_message)
        key = key_for(delayed_message)
        Cenit::Redis.pipelined do |redis|
          redis.del key
          redis.zrem(SET_KEY, key)
        end
      end

      def hash_for(delayed_message)
        return delayed_message if delayed_message.is_a?(Hash)
        {
          id: delayed_message[:id].to_s,
          tenant_id: delayed_message[:tenant_id].to_s,
          message: delayed_message[:message],
          unscheduled: delayed_message[:unscheduled].to_b
        }
      end

      def reschedule(delayed_message, publish_at)
        Cenit::Redis.zadd(SET_KEY, publish_at.to_i, key_for(delayed_message))
      end

      def for_each_ready(opts = {}, &block)
        return unless block
        now = opts[:at] || Time.now
        opts =
          if (limit = opts[:limit])
            { limit: [0, limit] }
          else
            {}
          end
        Cenit::Redis.zrangebyscore(SET_KEY, 0, now.to_i, opts).each do |key|
          delayed_message = get(key)
          delayed_message && block.call(delayed_message)
        end
      end
    end

    class << self

      def adapter
        @adapter ||=
          if Cenit::Redis.client?
            RedisAdapter
          else
            MongoidAdapter
          end
      end

      delegate :set_load_on_start,
               :load_on_start?,
               :reschedule,
               :for_each_ready,

               to: :adapter

      def load_on_start
        adapter.load_on_start do
          count = 0
          all.each do |delayed_message|
            count += 1
            delayed_message.send_to_adapter
          end
          puts "#{count} delayed messages loaded"
        end
      end

      def default_publish_at
        Time.now + (Cenit.default_delay || Cenit.scheduler_lookup_interval || 0)
      end
    end
  end
end
