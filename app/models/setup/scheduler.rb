module Setup
  class Scheduler < Event

    BuildInDataType.regist(self).referenced_by(:namespace, :name).excluding(:last_trigger_timestamps, :scheduler_id)

    field :scheduling_method, type: Symbol
    field :expression, type: String
    field :activated, type: Boolean, default: false

    has_many :delayed_messages, class_name: Setup::DelayedMessage.to_s, inverse_of: :scheduler

    validates_presence_of :name, :scheduling_method

    scope :activated, -> { where(activated: true) }

    validate do
      errors.add(:expression, "can't be blank") unless (exp = expression).present?
      case scheduling_method
      when :Once
        errors.add(:expression, 'is not a valid date-time') unless !(DateTime.parse(exp) rescue nil)
      when :Periodic
        if exp =~ /\A[1-9][0-9]*(s|m|h|d)\Z/
          if interval < (min = (Cenit.min_scheduler_interval || 60))
            self.expression = "#{min}s"
          end
        else
          errors.add(:expression, 'is not a valid interval')
        end
      when :CRON
        #TODO Validate CRON Expression
        #errors.add(:expression, 'is not a valid CRON expression') unless exp =~ /\A(0|[1-5][0-9]?|[6-9]|\*) (0|1[0-9]?|2[0-3]?|[3-9]|\*) ([1-2][0-9]?|3[0-1]?|[4-9]|\*)  (1[0-2]?|[2-9]|\*) (\*)\Z/
      else
        errors.add(:scheduling_method, 'is not a valid scheduling method')
      end
      errors.blank?
    end

    before_save do
      @activation_status_changed = changed_attributes.has_key?(:activated.to_s)
      true
    end

    after_save { (activated ? start : stop) if @activation_status_changed }

    before_destroy { stop }

    def scheduling_method_enum
      [:Periodic] #[:Once, :Periodic, :CRON]
    end

    def ready_to_save?
      scheduling_method.present?
    end

    def activated?
      activated.present?
    end

    def deactivated?
      !activated?
    end

    def start
      Setup::Flow.where(event: self).each do |flow|
        if (flows_executions = Setup::FlowExecution.where(flow: flow, scheduler: self)).present?
          flows_executions.each { |flow_execution| flow_execution.retry if flow_execution.can_retry? }
        else
          flow.process(scheduler: self)
        end
      end
    end

    def stop
      delayed_messages.update_all(unscheduled: true)
    end

    def activate
      update(activated: true) unless activated?
    end

    def deactivate
      update(activated: false) unless deactivated?
    end

    def interval
      case scheduling_method
      when :Once
        Time.now - DateTime.parse(expression) rescue 0
      when :Periodic
        expression.to_s.to_seconds_interval
      when :CRON
        #TODO Next CRON Time
        0
      else
        0
      end
    end

    def next_time
      Time.now + interval
    end
  end
end


class String
  def to_seconds_interval
    case last
    when 's'
      1
    when 'm'
      60
    when 'h'
      60 * 60
    when 'd'
      24 * 60 * 60
    else
      0
    end * chop.to_i
  end
end