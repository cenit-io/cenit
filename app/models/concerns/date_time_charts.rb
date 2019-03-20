module DateTimeCharts
  extend ActiveSupport::Concern
  module ClassMethods
    def data_by(set, base_calc, date_field, calculation, acumulate = nil)
      set = set.group_by { |o| acumulate.present? ? o.send(date_field).send(acumulate) : o.send(date_field) }
      met = simple_properties_schemas.key?(base_calc.to_s) ? "map(&:#{base_calc})" : "send(:#{base_calc})" # TODO: Check aggregation calculation when base_calc is a relation
      proc = eval "lambda { |collection| collection.#{met}.#{calculation} }"
      set = acumulate =~ /^beginning_of/ ? set.map { |k, v| [k, proc.call(v)] } : set.sort.map { |c| [send(acumulate)[c[0]], proc.call(c[1])] }
      [{ data: set }]
    end

    def wday
      Date::DAYNAMES
    end

    def hour
      %w(12am 1am 2am 3am 4am 5am 6am 7am 8am 9am 10am 11am 12m 1pm 2pm 3pm 4pm 5pm 6pm 7pm 8pm 9pm 10pm 11pm)
    end
  end
end
