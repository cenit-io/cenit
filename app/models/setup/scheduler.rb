module Setup
  class Scheduler < Event

    BuildInDataType.regist(self)
        .with(:namespace, :name, :scheduling_method, :expression, :advanced_expression, :activated)
        .referenced_by(:namespace, :name)

    field :scheduling_method, type: Symbol
    field :expression, type: String
    field :advanced_expression, type: String
    field :activated, type: Boolean, default: false

    has_many :delayed_messages, class_name: Setup::DelayedMessage.to_s, inverse_of: :scheduler

    validates_presence_of :name, :scheduling_method

    scope :activated, -> { where(activated: true) }

    validate do
      # errors.add(:expression, "can't be blank") unless (exp = expression).present?

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
        when :Advanced

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

    def custom_title
      super + ' [' + (activated? ? 'on' : 'off') + ']'
    end

    def scheduling_method_enum
      [:Periodic, :Advanced] #[:Once, :Periodic, :CRON]
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
      retryed_tasks_ids = Set.new
      Setup::Task.where(scheduler: self).each do |task|
        if task.can_retry?
          task.retry
          retryed_tasks_ids << task.id
        end
      end
      Setup::Flow.where(event: self).each do |flow|
        if (flows_executions = Setup::FlowExecution.where(flow: flow, scheduler: self)).present?
          flows_executions.each { |flow_execution| flow_execution.retry if !retryed_tasks_ids.include?(flow_execution.id) && flow_execution.can_retry? }
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
          Time.now - DateTime.parse(expression).to_time rescue 0
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
      if scheduling_method != :Advanced
        Time.now + interval
      else
        calculator = SchedulerTimePointsCalculator.new(JSON.parse(advanced_expression), Time.now.year)
        calculator.run
        calculator.next_time(Time.now)
      end
    end

  end


  class SchedulerTimePointsCalculator

    def amount_of_days(year, month)
      res = {
          1 => 31, 3 => 31,
          5 => 31, 7 => 31,
          8 => 31, 10 => 31,
          12 => 31,
      }
      res = res[month]
      if not res
        dt = Time.gm(year, month+1, 1)
        res = (dt-1).day
      end
      res
    end


    def thow_first_days(year, dd, m)
      res = []
      one_day = 60*60*24
      d1 = Time.gm(year, m, 1)
      d2 = Time.gm(year, m, 21)
      sunday = d1 + ((7 + dd - d1.wday) % 7) * one_day
      while sunday < d2
        res << sunday.day
        sunday += one_day * 7
      end
      res
    end

    def all_days(year, dd, m)
      res = []
      one_day = 60*60*24
      d1 = Time.gm(year, m, 1)
      d2 = Time.gm(year, m, amount_of_days(year, m))
      sunday = d1 + ((7 + dd - d1.wday) % 7) * one_day
      while sunday < d2
        res << sunday.day
        sunday += one_day * 7
      end
      res
    end

    def last_day(year, dd, m)
      one_day = 60*60*24
      d1 = Time.gm(year, m, amount_of_days(year, m))
      while d1.wday != dd
        d1 -= one_day
      end
      d1
    end

    def thow_last_days(year, dd, m)
      res = []
      one_day = 60*60*24
      d1 = Time.gm(year, m, amount_of_days(year, m))
      d2 = Time.gm(year, m, amount_of_days(year, m) - 14)
      sunday = last_day(year, dd, m)

      while sunday > d2
        res << sunday.day
        sunday -= one_day * 7
      end
      res
    end

    def days

      months_days = @conf["months_days"]
      weeks_days = @conf["weeks_days"]
      if weeks_days == [] and months_days == []
        months_days = [1]
      else
        # weeks_days exists!
        if months_days == []
          # Obtener los dias de acuerdo a la(s) semana(s)
          month = @solution[0]
          weeks_month = @conf["weeks_month"]

          if weeks_month.length > 0
            weeks_month.each do |wm|
              if wm > 0
                # firsts one
                months_days += weeks_days.collect do |wd|
                  thow_first_days(@year, wd, month)[wm-1]
                end
              else
                # lasts one
                months_days += weeks_days.collect do |wd|
                  thow_last_days(@year, wd, month)[wm.abs - 1]
                end
              end
            end
          else
            months_days = weeks_days.collect do |wd|
              all_days(@year, wd, month)
            end
            months_days.flatten
          end

        end
      end
      months_days
    end

    def hours
      res = @conf["hours"]
      if res == []
        res = [0]
      end
      res
    end

    def minutes
      res = @conf["minutes"]
      if res == []
        res = [0]
      end
      res
    end

    def months
      res = @conf["months"]
      if res == []
        res = [1]
      end
      res

    end

    def initialize(conf, year)
      @conf = conf
      @actions = [->() { months }, ->() { days }, ->() { hours }, ->() { minutes }]
      @year = year
    end

    def run
      @solution = [0, 0, 0, 0]
      @v = []
      backtracking(0)
      @v
    end

    def report_solution
      # TODO: To use the user TimeZone
      @v << Time.new(@year, *@solution, 0, "-04:00")
    end

    def backtracking(k)
      if k > 3
        report_solution()
      else
        @actions[k].call.each { |e|
          @solution[k] = e
          backtracking(k+1)
        }
      end
    end

    def next_time(tnow)
      @v.select { |e| e > tnow }
          .collect { |e| e - tnow }
          .min
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
