module Setup
  class Scheduler < Event
    include HashField
    include RailsAdmin::Models::Setup::SchedulerAdmin
    # = Scheduler
    #
    # Are events triggered on a certain moment and can be optionally recurrent.
    #
    # Options can be specified for the moment the scheduler would be triggered for the first time,
    # if and how it should be rescheduled and finally when should it stop.
    #
    # All this options default to a 'Start on activation, run every day' setting.
    # If the scheduler should not start immediately after activation, a date can be specified for it.
    #
    # Schedulers can be a one-time execution, or a specific periodicity, but can also be triggered on appointed dates.
    # For periodical executions choose the 'Every ...' option, enter a number in the input box and select the time span.
    #
    # Otherwise, for appointed dates choose the 'Select manually'.
    # The first thing for manual scheduling would be to specify the time of day the scheduler should be triggered at
    # and then decide on a week-based approach or a month-based approach:
    #
    # Week-based: Note selected weekdays and months on the year, this setting would have the scheduler trigger on
    # the Last Sunday of June and December.
    #
    # Month-based: this setting would have the scheduler trigger on the 14th and Last day of June and December.
    #
    # It would be good to notice that for any specific setting on the manual approach, selecting no item is the same as selecting all of them.
    # That is, if a scheduler is to be triggered everyday of the month in June, check only the month June and leave all days unchecked.
    # You could off course check each individual day by yourself, but it is an unnecessary trouble. This rule applies to Week-based
    # approach as well.
    # Finally, task can be scheduled to end, so that it does not get queued for execution passed some date, it is very much
    # like the starting date setting.

    build_in_data_type.with(:namespace, :name, :expression, :activated).referenced_by(:namespace, :name)

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

    def check_before_save
      @activation_status_changed = changed_attributes.key?(:activated.to_s)
      # if expression['type'] == 'cyclic'
      #   self.expression = { type: 'cyclic', cyclic_expression: expression['cyclic_expression'] }
      # else
      expression.reject! { |_, value| value.blank? }
      # end
      errors.blank?
    end

    after_save { (activated ? start : stop) if @activation_status_changed }

    before_destroy { stop }

    def custom_title
      super + ' [' + (activated? ? 'on' : 'off') + ']' +
        (origin == :admin ? ' (ADMIN)' : '')
    end

    def activated?
      activated.present?
    end

    def deactivated?
      !activated?
    end

    def start
      return unless next_time
      Setup::Task.where(scheduler: self).each do |task|
        task.retry(action: :scheduled) unless TaskToken.where(task_id: task.id).exists?
      end
      Setup::Flow.where(event: self).each do |flow|
        flow.process(scheduler: self) unless Setup::FlowExecution.where(flow: flow, scheduler: self).exists?
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
      calculator = SchedulerTimePointsCalculator.new(expression, Time.now.year, Account.current.time_zone_offset)
      (next_time = calculator.next_time(Time.now.utc)) && next_time.localtime
    end

    SCHEMA = {
      type: 'object',
      properties: {
        cyclic_expression: {
          type: 'string',
          pattern: '^[1-9][0-9]*(s|m|h|d|w|M)$'
        },
        type: {
          type: 'string',
          enum: %w(cyclic appointed)
        },
        months_days: {
          type: 'array',
          items: {
            type: 'integer'
          },
          uniqueItems: true,
          maxItems: 31
        },
        weeks_days: {
          type: 'array',
          items: {
            type: 'integer'
          },
          uniqueItems: true,
          maxItems: 7
        },
        weeks_month: {
          type: 'array',
          items: {
            type: 'integer'
          },
          uniqueItems: true,
          maxItems: 5
        },
        months: {
          type: 'array',
          items: {
            type: 'integer'
          },
          uniqueItems: true,
          maxItems: 12
        },
        hours: {
          type: 'array',
          items: {
            type: 'integer'
          },
          uniqueItems: true,
          maxItems: 24
        },
        minutes: {
          type: 'array',
          items: {
            type: 'integer'
          },
          uniqueItems: true,
          maxItems: 60
        },
        last_day_in_month: {
          type: 'boolean'
        },
        last_week_in_month: {
          type: 'boolean'
        },
        start_at: {
          type: 'string',
          pattern: '^\d\d\d\d-(0?[1-9]|1[0-2])-(0?[1-9]|[12][0-9]|3[01])$'
        },
        frequency: {
          type: 'integer'
        },
        end_at: {
          type: 'string',
          pattern: '^\d\d\d\d-(0?[1-9]|1[0-2])-(0?[1-9]|[12][0-9]|3[01])$'
        },
        max_repeat: {
          type: 'integer'
        }
      },
      required: %w(type),
      additionalProperties: false
    }.to_json
  end


  class SchedulerTimePointsCalculator

    THIRTY_ONE_MONTHS = Set.new [1, 3, 5, 7, 8, 10, 12]

    def amount_of_days_in_the_month(year, month)
      if THIRTY_ONE_MONTHS.include?(month)
        31
      else
        (Time.gm(year, month + 1, 1) - 1).day
      end
    end


    def weeks_first_days(year, dd, m)
      res = []
      d1 = Time.gm(year, m, 1)
      d2 = Time.gm(year, m, 21)
      sunday = d1 + ((7 + dd - d1.wday) % 7) * 1.day
      while sunday < d2
        res << sunday.day
        sunday += 1.day * 7
      end
      res
    end

    def all_days(year, dd, m)
      res = []
      d1 = Time.gm(year, m, 1)
      d2 = Time.gm(year, m, amount_of_days_in_the_month(year, m))
      sunday = d1 + ((7 + dd - d1.wday) % 7) * 1.day
      while sunday < d2
        res << sunday.day
        sunday += 1.day * 7
      end
      res
    end

    def last_day(year, dd, m)
      d1 = Time.gm(year, m, amount_of_days_in_the_month(year, m))
      d1 -= 1.day while d1.wday != dd
      d1
    end

    def weeks_last_days(year, dd, m)
      res = []
      d2 = Time.gm(year, m, amount_of_days_in_the_month(year, m) - 14)
      sunday = last_day(year, dd, m)
      while sunday > d2
        res << sunday.day
        sunday -= 1.day * 7
      end
      res
    end

    def days
      month = @solution[0]
      weeks_days = @conf[:weeks_days]
      weeks_days = (0..6).to_a if weeks_days.blank?
      weeks_month = @conf[:weeks_month]
      weeks_month = (0..3).to_a if weeks_month.blank?
      a = amount_of_days_in_the_month(@year, month)

      if @conf[:type] == 'appointed_position'
        months_days = []
        # Retrieve days by weeks
        if weeks_month.length.positive?
          weeks_month.each do |wm|
            if wm.positive?
              # firsts one
              months_days += weeks_days.collect { |wd| weeks_first_days(@year, wd, month)[wm - 1] }
            else
              # lasts one
              months_days += weeks_days.collect { |wd| weeks_last_days(@year, wd, month)[wm.abs - 1] }
            end
          end
        else
          months_days = weeks_days.collect { |wd| all_days(@year, wd, month) }
          months_days.flatten!
        end
        months_days << a if @conf[:last_day_in_month] && !months_days.include?(a)
      else
        months_days = @conf[:months_days]
      end

      months_days = (1..a).to_a if months_days.blank?

      months_days.select { |e| e.positive? && e <= a }
    end

    def hours
      res = @conf[:hours]
      res = (0..23).to_a if res.blank?
      res.select { |e| e > -1 && e <= 23 }
    end

    def minutes
      res = @conf[:minutes]
      res = (1..59).to_a if res.blank?
      res.select { |e| e > -1 && e <= 59 }
    end

    def months
      res = @conf[:months]
      res = (1..12).to_a if res.blank?
      res.select { |e| e.positive? && e <= 12 }
    end

    def initialize(conf, year, tz)
      conf = JSON.parse(conf.to_s) unless conf.is_a?(Hash)
      @conf = conf.deep_symbolize_keys
      @actions = [->() { months }, ->() { days }, ->() { hours }, ->() { minutes }]
      @year = year
      @tz = tz
    end

    def run(now)
      @solution = [now.month, now.day, now.hour, now.min]
      @v = []
      backtracking(0)
      @v
    end

    def report_solution
      @v << Time.new(@year, *@solution, 0, @tz)
    end

    def backtracking(k)
      if k > 3
        report_solution
      else
        @actions[k].call.each do |e|
          @solution[k] = e
          backtracking(k + 1)
        end
      end
    end

    def next_time(now)
      case @conf[:type]
      when 'cyclic'
        a = @conf[:cyclic_expression].to_seconds_interval
        b = Cenit.min_scheduler_interval || 60
        now + [a, b].max
      when 'appointed'
        run(now)
        res = @v.select { |e| e > now }.collect { |e| e - now }.min
        res ? now + res : nil
      else
        nil # Unknown scheduling type
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
