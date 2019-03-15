module Setup
  module TriggersFormatter
    def format_triggers_on(field, required = false)
      begin
        send("#{field}=", json = send(field).gsub('=>', ':'))
        hash = JSON.parse(json)
        hash.delete('_')
        if required && hash.blank?
          send("#{field}=", nil)
          errors.add(field, "can't be blank")
          return false
        end
        send("#{field}=", hash.to_json)
      rescue
        errors.add(field, 'is not valid')
        return false
      end
      modified = nil
      hash.each do |field, conditions|
        # LEGACY: Transform form old Hash conditions format to new Array conditions format.
        if conditions.is_a?(Hash)
          hash[field] = conditions = conditions.values
          modified = true
        end

        conditions.each do |condition|
          if condition['o'].nil? && %w(_null _not_null _change _presence_change).include?(condition['v'])
            condition['o'] = condition.delete('v')
            modified = true
          end
        end
      end
      send("#{field}=", hash.to_json) if modified
    end

    def field_triggers_apply_to?(field, obj_now, obj_before = nil)
      r = true
      triggers_hash = JSON.parse(send(field))
      triggers_hash.each do |field_name, conditions|
        # LEGACY: Transform form old Hash conditions format to new Array conditions format.
        conditions = conditions.values if conditions.is_a?(Hash)

        conditions.each do |condition|
          if %w(_change _presence_change).include?(condition['o'])
            r &&= !(condition['o'] == '_presence_change' && obj_before.nil?) &&
              field_changed(obj_now, obj_before, field_name)
          else
            r &&= condition_apply(obj_now, obj_before, field_name, condition) &&
              (obj_before.nil? || !condition_apply(obj_before, obj_now, field_name, condition))
          end
        end
      end
      r
    end

    private

    def field_changed(obj_now, obj_before, field_name)
      obj_now.try(field_name) != obj_before.try(field_name)
    end

    def condition_apply(obj, before, field_name, condition)
      obj_v = obj.try(field_name)
      cond_v = valuate(condition['v'], obj_v.class)
      obj_values =
        if cond_v.is_a?(String) || (cond_v.is_a?(Array) && cond_v.detect { |e| e.is_a?(String) })
          convert_to_string_array(obj_v)
        else
          [obj_v]
        end
      unless (op = condition['o'])
        op = cond_v.is_a?(Array) ? 'in' : 'is'
      end
      applier_method = "op_#{op}"
      if respond_to?(applier_method, true)
        applier_method = method(applier_method)
        args = []
        if applier_method.arity > 1
          args << cond_v
        end
        if applier_method.arity > 2
          args << before
        end
        obj_values.each { |v| return true if applier_method.call(*([v] + args)) }
      end
      false
    end

    def convert_to_string_array(obj_v)
      return [obj_v] if obj_v.is_a?(String)
      array = [:name, :title, :id].map { |property| obj_v.send(property).to_s rescue next }
      array << obj_v.to_s if array.empty?
      array
    end

    CONVERSION_METHOD =
      {
        NilClass => :to_s,
        Integer => :to_f,
        Fixnum => :to_f,
        Float => :to_f,
        String => :to_s,
        Date => :to_date,
        DateTime => :to_datetime,
        Time => :to_time,
        ActiveSupport::TimeWithZone => :to_time,
        FalseClass => :to_b,
        TrueClass => :to_b,
        BigDecimal => :to_d
      }

    def valuate(cond_v, klass)
      return if cond_v.nil?
      return cond_v if cond_v.is_a?(klass)
      cond_v = [cond_v] unless (is_array = cond_v.is_a?(Array))
      to_obj_class = CONVERSION_METHOD[klass]
      cond_v = cond_v.collect do |e|
        case
        when e.nil? || (e.is_a?(String) && e.empty?)
          nil
        when to_obj_class.nil?
          e
        else
          e.to_s.send(to_obj_class) rescue e
        end
      end
      is_array ? cond_v : cond_v[0]
    end

    def op_like(obj_v, cond_v)
      if obj_v.nil?
        cond_v.nil?
      else
        cond_v.nil? ? false : !obj_v.to_s[cond_v.to_s].nil?
      end
    end

    def op_is(obj_v, cond_v)
      obj_v == cond_v
    end

    def op_starts_with(obj_v, cond_v)
      if obj_v.nil?
        cond_v.nil?
      else
        cond_v.nil? ? false : obj_v.to_s.start_with?(cond_v.to_s)
      end
    end

    def op_ends_with(obj_v, cond_v)
      if obj_v.nil?
        cond_v.nil?
      else
        cond_v.nil? ? false : obj_v.to_s.end_with?(cond_v.to_s)
      end
    end

    def op__not_null(obj_v, cond_v, before)
      !op__null(obj_v, cond_v, before)
    end

    def op__null(obj_v, cond_v, before)
      obj_v.blank? && (before.nil? || cond_v.present?)
    end

    def op_in(obj_v, cond_v)
      cond_v.include?(obj_v) rescue false
    end

    def op_default(obj_v, cond_v)
      op_is(obj_v, cond_v.nil? ? nil : cond_v[0])
    end

    def op_between(obj_v, cond_v)
      return false if obj_v.nil? || cond_v.nil?
      min = cond_v[1].nil? ? true : obj_v >= cond_v[1]
      max = cond_v[2].nil? ? true : obj_v <= cond_v[2]
      min && max
    end

    def op_today(obj_v)
      op_between(obj_v, [nil, Date.today.at_beginning_of_day, Date.today.at_end_of_day])
    end

    def op_yesterday(obj_v)
      op_between(obj_v, [nil, Date.yesterday.at_beginning_of_day, Date.yesterday.at_end_of_day])
    end

    def op_this_week(obj_v)
      op_between(obj_v, [nil, Date.today.at_beginning_of_week.at_beginning_of_day, Date.today.at_end_of_week.at_end_of_day])
    end

    def op_last_week(obj_v)
      op_between(obj_v, [nil, (last_week_beginning = Date.today.weeks_ago(1).at_beginning_of_week).at_beginning_of_day, last_week_beginning.at_end_of_week.at_end_of_day])
    end
  end
end
