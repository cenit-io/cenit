module RailsAdmin
  module SchedulerHelper
    def dh
      dd = Hash.new { |h, k| h[k] = [] }
      dd['cyclic_expression'] = ''
      dd['now'] = Time.now.strftime '%Y-%m-%d %H:%M'
      dd['frequency'] = 0
      if @object.expression != nil
        dd.merge!(@object.expression)
        if dd['type'] == 'cyclic'
          dd['frequency'] = %w(m d w M).find_index(dd['cyclic_expression'][-1])
        else
          if dd.has_key? 'hours'
            dd['frequency'] = 1
          elsif (dd.has_key? 'week_days') or (dd.has_key? 'month_days') or (dd.has_key? 'last_day_in_month')
            dd['frequency'] = 2
          elsif (dd.has_key? 'weeks_month') or (dd.has_key? 'last_week_in_month')
            dd['frequency'] = 3
          elsif dd.has_key? 'months'
            dd['frequency'] = 4
          end
        end
      else
        dd['type'] = 'cyclic'
        %w(months_days months hours minutes).each { |e| dd[e] = dd[e].to_s.strip[1..-2] }
        dd['frequency'] = 2
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