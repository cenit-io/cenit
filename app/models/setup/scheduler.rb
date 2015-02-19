module Setup
  class Scheduler < Event

    BuildInDataType.regist(self).referenced_by(:name).excluding(:last_trigger_timestamps, :scheduler_id)

    field :scheduling_method, type: Symbol
    field :expression, type: String
    field :scheduler_id, type: Integer

    validates_presence_of :name, :scheduling_method

    validate do
      errors.add(:expression, "can't be blank") unless exp = expression
      case scheduling_method
        when :Once
          errors.add(:expression, 'is not a valid date-time') unless !(DateTime.parse(exp) rescue nil)
        when :Periodic
          errors.add(:expression, 'is not a valid interval') unless exp =~ /\A[1-9][0-9]*(s|m|h|d)\Z/
        when :CRON
          #TODO Validate CRON Expression
          #errors.add(:expression, 'is not a valid CRON expression') unless exp =~ /\A(0|[1-5][0-9]?|[6-9]|\*) (0|1[0-9]?|2[0-3]?|[3-9]|\*) ([1-2][0-9]?|3[0-1]?|[4-9]|\*)  (1[0-2]?|[2-9]|\*) (\*)\Z/
        else
          errors.add(:scheduling_method, 'is not a valid scheduling method')
      end
    end

    before_save :configure_scheduler
    after_save :start
    before_destroy :stop

    def scheduling_method_enum
      [:Once, :Periodic, :CRON]
    end

    def rufus_method
      case scheduling_method
        when :Once
          :at
        when :Periodic
          :every
        when :CRON
          :cron
        else
          nil
      end
    end

    def ready_to_save?
      scheduling_method.present?
    end

    def can_be_restarted?
      ready_to_save?
    end

    def configure_scheduler
      unless started? && Setup::Scheduler.mutex_for(self).owned? # triggering
        stop
        scheduler = Rufus::Scheduler.new
        self.scheduler_id = scheduler.object_id
        puts "Scheduler #{name} configured!"
        self.name = "Scheduler #{scheduler_id}" unless name
        scheduler
      end
    end

    def scheduler_instance
      if scheduler = ObjectSpace._id2ref(scheduler_id) rescue nil
        scheduler
      else
        configure_scheduler
      end
    end

    def started?
      scheduler = ObjectSpace._id2ref(scheduler_id) rescue nil
      scheduler.is_a?(Rufus::Scheduler) && scheduler.instance_variable_get(:@started_on_cenit)
    end

    def start
      unless started?
        (scheduler = scheduler_instance).instance_variable_set(:@started_on_cenit, true)
        scheduler.send(rufus_method, expression) do
          Setup::Scheduler.lookup(self)
        end
        puts "Scheduler #{name} started..."
      end
    end

    def stop
      begin
        if scheduler_id && (scheduler = ObjectSpace._id2ref(scheduler_id)).is_a?(Rufus::Scheduler)
          scheduler.stop
          puts "Scheduler #{name} stoped!"
        end
      rescue
        puts "No scheduler instance detected for #{name}"
      end
      self.scheduler_id = nil
    end

    def self.lookup(scheduler_event)
      (mutex = mutex_for(scheduler_event)).lock
      puts "TRIGGERING #{scheduler_event.name}..."
      Setup::Flow.where(event: scheduler_event).each { |f| f.process }
      scheduler_event.last_trigger_timestamps = DateTime.now
      scheduler_event.save
      mutex.unlock
    end

    def self.mutex_for(scheduler)
      @mutexs ||= Hash.new { |hash, key| hash[key] = Mutex.new }
      @mutexs[scheduler.id.to_s] if scheduler.is_a?(Setup::Scheduler)
    end
  end
end
