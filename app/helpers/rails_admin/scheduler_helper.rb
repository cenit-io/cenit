module RailsAdmin
  module SchedulerHelper
    def dh
      dd = Hash.new { |h, k| h[k] = [] }
      dd['now'] = Time.now.strftime '%Y-%m-%d'
      dd['type'] = 'cyclic'
      dd['cyclic_expression'] = '1d'
      dd['frequency'] = 1
      if (@object.expression != nil) and (@object.expression.has_key? 'type')
        dd.merge!(@object.expression)
        if dd['type'].start_with? 'appointed'
          dd['frequency'] = 2
        elsif dd['type'] == 'once'
          dd['frequency'] = 0
        end
      end
      dd
    end

    def cyclic_as_hours
      exp = dh['cyclic_expression']
      if exp.ends_with? 'm'
        m = exp[0..-1].to_i
        h = m / 60
        m = m % 60
        return h, m
      end
      return 1, 0
    end

    def sch_week_days
      t('admin.scheduler.days.names').split(' ')
    end

    def sch_month_weeks
      t('admin.scheduler.weeks.month').split(' ')
    end

    def sch_month_names
      t('admin.scheduler.months.names').split(' ')
    end

    def months_span
      [2, 3, 4, 6]
    end

    def days_span
      [2, 3, 5, 7, 14]
    end

    def hours_span
      [2, 3, 4, 6, 12]
    end

    def minutes_span
      [2, 4, 5, 10, 15, 20, 30]
    end
  end
end