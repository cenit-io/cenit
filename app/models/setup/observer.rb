module Setup
  class Observer < Event
    include TriggersFormatter

    BuildInDataType.regist(self).referenced_by(:name).excluding(:last_trigger_timestamps).including(:data_type)

    belongs_to :data_type, class_name: Setup::DataType.to_s, inverse_of: :events
    field :triggers, type: String

    validates_presence_of :data_type, :triggers

    before_save :format_triggers, :check_name

    def ready_to_save?
      data_type.present?
    end

    def can_be_restarted?
      ready_to_save?
    end

    def to_s
      name ? name : super
    end

    def triggers_apply_to?(obj_now, obj_before = nil)
      field_triggers_apply_to?(:triggers, obj_now, obj_before)
    end

    class << self
      def lookup(obj_now, obj_before = nil)
        where(data_type: obj_now.orm_model.data_type).each do |e|
          next unless e.triggers_apply_to?(obj_now, obj_before)
          Setup::Flow.where(active: true, event: e).each { |f| f.process(source_id: obj_now.id.to_s) }
        end
      end
    end

    private

    def format_triggers
      format_triggers_on(:triggers)
    end

    def check_name
      if name.blank?
        hash = JSON.parse(triggers)
        triggered_fields = hash.keys
        n = "#{self.data_type.custom_title} on #{triggered_fields.to_sentence}"
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
