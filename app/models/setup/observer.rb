module Setup
  class Observer < Event

    BuildInDataType.regist(self).referenced_by(:name).excluding(:last_trigger_timestamps).including(:data_type)

    belongs_to :data_type, class_name: Setup::Model.to_s, inverse_of: :events
    field :triggers, type: String

    validates_presence_of :data_type, :triggers

    before_save :format_triggers, :check_name

    def ready_to_save?
      data_type.present?
    end

    def can_be_restarted?
      ready_to_save?
    end

    def triggers_apply_to?(obj_now, obj_before = nil)
      r = true
      triggers_hash = JSON.parse(self.triggers)
      triggers_hash.each do |field_name, conditions|
        conditions.each do |_, condition|
          r &&=
            if (condition['o'] == '_change')
              field_changed(obj_now, obj_before, field_name)
            else
              condition_apply(obj_now, field_name, condition) && !condition_apply(obj_before, field_name, condition)
            end
        end
      end
      puts "Event '#{name ? name : self}' #{r ? '' : 'DOES NOT'} APPLIES!"
      r
    end

    def self.lookup(obj_now, obj_before = nil)
      where(data_type: obj_now.orm_model.data_type).each do |e|
        next unless e.triggers_apply_to?(obj_now, obj_before)
        Setup::Flow.where(active: true, event: e).each { |f| f.process(source_id: obj_now.id.to_s) }
      end
    end

    def to_s
      name ? name : super
    end

    private

    def field_changed(obj_now, obj_before, field_name)
      obj_now.try(field_name) != obj_before.try(field_name)
    end

    def condition_apply(obj, field_name, condition)
      obj_v = obj.try(field_name)
      cond_v = valuate(condition['v'], obj_v.class)
      obj_values =
        if cond_v.is_a?(String) || (cond_v.is_a?(Array) && cond_v.detect { |e| e.is_a?(String) })
          convert_to_string_array(obj_v)
        else
          [obj_v]
        end
      unless op = condition['o']
        op = cond_v.is_a?(Array) ? 'in' : 'is'
      end
      if respond_to?(applier_method = "op_#{op}", true)
        obj_values.each { |obj_v| return true if send(applier_method, obj_v, cond_v) }
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
        FalseClass => :to_boolean,
        TrueClass => :to_boolean,
        BigDecimal => :to_d
      }

    def valuate(cond_v, klass)
      return unless cond_v
      return cond_v if cond_v.is_a?(klass)
      cond_v = [cond_v] unless is_array = cond_v.is_a?(Array)
      to_obj_class = CONVERSION_METHOD[klass]
      cond_v = cond_v.collect do |e|
        case
        when e.nil? || (e.is_a?(String) && e.empty?)
          nil
        when to_obj_class.nil?
          e
        else
          e.to_s.try(to_obj_class) || e
        end
      end
      return is_array ? cond_v : cond_v[0]
    end

    def op_like(obj_v, cond_v)
      obj_v.nil? ? cond_v.nil? : (cond_v.nil? ? false : !obj_v.to_s[cond_v.to_s].nil?)
    end

    def op_is(obj_v, cond_v)
      obj_v == cond_v
    end

    def op_starts_with(obj_v, cond_v)
      obj_v.nil? ? cond_v.nil? : (cond_v.nil? ? false : obj_v.to_s.start_with?(cond_v.to_s))
    end

    def op_ends_with(obj_v, cond_v)
      obj_v.nil? ? cond_v.nil? : (cond_v.nil? ? false : obj_v.to_s.end_with?(cond_v.to_s))
    end

    def op__not_null(obj_v, cond_v)
      !op__null(obj_v, cond_v)
    end

    def op__null(obj_v, cond_v)
      obj_v.nil? || obj_v.to_s.empty?
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

    def op_today(obj_v, cond_v)
      op_between(obj_v, [nil, Date.today.at_beginning_of_day, Date.today.at_end_of_day])
    end

    def op_yesterday(obj_v, cond_v)
      op_between(obj_v, [nil, Date.yesterday.at_beginning_of_day, Date.yesterday.at_end_of_day])
    end

    def op_this_week(obj_v, cond_v)
      op_between(obj_v, [nil, Date.today.at_beginning_of_week.at_beginning_of_day, Date.today.at_end_of_week.at_end_of_day])
    end

    def op_last_week(obj_v, cond_v)
      op_between(obj_v, [nil, (last_week_beginning = Date.today.weeks_ago(1).at_beginning_of_week).at_beginning_of_day, last_week_beginning.at_end_of_week.at_end_of_day])
    end

    def format_triggers
      begin
        self.triggers = self.triggers.gsub('=>', ':')
        hash = JSON.parse(self.triggers)
        hash.delete('_')
        if hash.blank?
          errors.add(:triggers, "can't be blank")
          return false
        end
        self.triggers = hash.to_json
      rescue
        errors.add(:triggers, 'is not valid')
        return false
      end
      modified = nil
      hash.each do |_, conditions|
        conditions.each do |_, condition|
          modified = condition['o'] = condition.delete('v') if condition['o'].nil? && %w(_null _not_null _change).include?(condition['v'])
        end
      end
      self.triggers = hash.to_json if modified
    end

    def check_name
      if name.blank?
        hash = JSON.parse(triggers)
        triggered_fields = hash.keys
        n = "#{self.data_type.on_library_title} on #{triggered_fields.to_sentence}"
        i = 1
        self.name = n
        while Setup::Observer.where(name: name).present? do
          self.name = n + " (#{i+=1})"
        end
      end
    end
  end
end

class String
  def to_boolean
    self == 'true'
  end
end
