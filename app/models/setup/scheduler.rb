module Setup
  class Scheduler < Event
    include HashField

    BuildInDataType.regist(self).with(:namespace, :name, :expression, :activated).referenced_by(:namespace, :name)

    hash_field :expression
    field :activated, type: Boolean, default: false

    has_many :delayed_messages, class_name: Setup::DelayedMessage.to_s, inverse_of: :scheduler

    validates_presence_of :name

    scope :activated, -> { where(activated: true) }

    validate do
      begin
        JSON::Validator.validate!(SCHEMA, expression)
      rescue JSON::Schema::ValidationError => e
        errors.add(:expression, e.message)
      end
      errors.blank?
    end

    before_save do
      @activation_status_changed = changed_attributes.has_key?(:activated.to_s)
      expression.reject! { |_, value| value.blank? }
      true
    end

    after_save { (activated ? start : stop) if @activation_status_changed }

    before_destroy { stop }

    def custom_title
      super + ' [' + (activated? ? 'on' : 'off') + ']' +
        (origin == :admin ? ' (ADMIN)' : '')
    end

    def ready_to_save?
      true
    end

    def activated?
      activated.present?
    end

    def deactivated?
      !activated?
    end

    def start
      return unless next_time
      retried_tasks_ids = Set.new
      Setup::Task.where(scheduler: self).each do |task|
        if task.can_retry?
          task.retry(action: :scheduled)
          retried_tasks_ids << task.id
        end
      end
      Setup::Flow.where(event: self).each do |flow|
        if (flows_executions = Setup::FlowExecution.where(flow: flow, scheduler: self)).present?
          flows_executions.each { |flow_execution| flow_execution.retry if !retried_tasks_ids.include?(flow_execution.id) && flow_execution.can_retry? }
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

    def next_time
      r = Account.current.time_zone.split("|")
      tz = "+00:00"
      if r.length > 1
        tz = r[1].strip
      end
      calculator = SchedulerTimePointsCalculator.new(expression, Time.now.year, tz)
      calculator.next_time(Time.zone.now)
    end

    SCHEDULER_SCHEMA = <<-DATA
{
  "type" : "object",
  "properties": {
    "periodic_expression": {
      "type": "string",
      "pattern": "^[1-9][0-9]*(s|m|h|d)$"
    },
    "type": {
      "type": "string",
      "enum": ["periodic", "specific_position", "specific_number"]
    },
    "months_days": {
      "type": "array",
      "items":{
        "type": "integer"
      },
      "uniqueItems": true,
      "maxItems": 31
    },
    "weeks_days": {
      "type": "array",
      "items":{
        "type": "integer"
      },
      "uniqueItems": true,
      "maxItems": 7
    },
    "weeks_month": {
      "type": "array",
      "items":{
        "type": "integer"
      },
      "uniqueItems": true,
      "maxItems": 3
    },
    "months": {
      "type": "array",
      "items":{
        "type": "integer"
      },
      "uniqueItems": true,
      "maxItems": 12
    },
    "hours": {
      "type": "array",
      "items":{
        "type": "integer"
      },
      "uniqueItems": true,
      "maxItems": 24
    },
    "minutes": {
      "type": "array",
      "items":{
        "type": "integer"
      },
      "uniqueItems": true,
      "maxItems": 60
    }
  },
  "required":["type"]
}
    DATA

  end


  class SchedulerTimePointsCalculator

    def amount_of_days_in_the_month(year, month)
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
      d2 = Time.gm(year, m, amount_of_days_in_the_month(year, m))
      sunday = d1 + ((7 + dd - d1.wday) % 7) * one_day
      while sunday < d2
        res << sunday.day
        sunday += one_day * 7
      end
      res
    end

    def last_day(year, dd, m)
      one_day = 60*60*24
      d1 = Time.gm(year, m, amount_of_days_in_the_month(year, m))
      while d1.wday != dd
        d1 -= one_day
      end
      d1
    end

    def thow_last_days(year, dd, m)
      res = []
      one_day = 60*60*24
      d1 = Time.gm(year, m, amount_of_days_in_the_month(year, m))
      d2 = Time.gm(year, m, amount_of_days_in_the_month(year, m) - 14)
      sunday = last_day(year, dd, m)

      while sunday > d2
        res << sunday.day
        sunday -= one_day * 7
      end
      res
    end

    def days
      month = @solution[0]
      weeks_days = @conf[:weeks_days]
      weeks_month = @conf[:weeks_month]
      _a = amount_of_days_in_the_month(@year, month)

      if @conf[:type] == 'appointed_position'
        months_days = []
        # Retrieve days by weeks
        if weeks_month.length > 0
          weeks_month.each do |wm|
            if wm > 0
              # firsts one
              months_days += weeks_days.collect { |wd| thow_first_days(@year, wd, month)[wm-1] }
            else
              # lasts one
              months_days += weeks_days.collect { |wd| thow_last_days(@year, wd, month)[wm.abs - 1] }
            end
          end
        else
          months_days = weeks_days.collect { |wd| all_days(@year, wd, month) }
          months_days.flatten!
        end
        months_days << _a if @conf[:last_day_in_month] and not months_days.include?(_a)
      else
        months_days = @conf[:months_days]
      end

      if months_days == []
        months_days = [1]
      end

      months_days.select { |e| e > 0 && e <= _a }
    end

    def hours
      res = @conf[:hours]
      if res == []
        res = [0]
      end
      res.select { |e| e > -1 && e <= 23 }
    end

    def minutes
      res = @conf[:minutes]
      if res == []
        res = [0]
      end
      res.select { |e| e > -1 && e <= 59 }
    end

    def months
      res = @conf[:months]
      if res == []
        res = [1]
      end
      res.select { |e| e > 0 && e <= 12 }
    end

    def initialize(conf, year, tz)
      conf = JSON.parse(conf.to_s) unless conf.is_a?(Hash)
      @conf = conf.deep_symbolize_keys
      @actions = [->() { months }, ->() { days }, ->() { hours }, ->() { minutes }]
      @year = year
      @tz = tz
    end

    def run
      @solution = [0, 0, 0, 0]
      @v = []
      backtracking(0)
      @v
    end

    def report_solution
      @v << Time.new(@year, *@solution, 0, @tz)
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
      if @conf[:type] != 'cyclic'
        run
        res = @v.select { |e| e > tnow }
                .collect { |e| e - tnow }
                .min
        res ? tnow + res : nil
      else
        a = @conf[:cyclic_expression].to_seconds_interval
        b = Cenit.min_scheduler_interval || 60
        tnow + [a, b].max
      end
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
