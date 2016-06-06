module RailsAdmin
  module SchedulerHelper
    def dd
      dd = Hash.new { |h, k| h[k] = [] }
      dd['cyclic_expression'] = ''
      if @object.expression != nil
        dd.merge!(@object.expression)
      else
        dd['type'] = 'cyclic'
        %w(months_days months hours minutes).each { |e| dd[e] = dd[e].to_s.strip[1..-2] }
      end
      dd
    end

    def week_days
      t('admin.scheduler.days.names').split(' ')
    end

    def weeks_month
      t('admin.scheduler.weeks.month').split(' ')
    end

    def hours_span
      [2, 3, 4, 6, 12]
    end

    def minutes_span
      [2, 4, 5, 10, 15, 20, 30]
    end
  end
end