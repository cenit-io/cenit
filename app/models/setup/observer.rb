module Setup
  class Observer < Event
    include TriggersFormatter
    include RailsAdmin::Models::Setup::ObserverAdmin
    # = Observer
    #
    # Creation of new objects or changes in objects will result in events.

    build_in_data_type.referenced_by(:namespace, :name).excluding(:origin)

    belongs_to :data_type, :class_name => Setup::DataType.name, inverse_of: nil
    belongs_to :trigger_evaluator, :class_name => Setup::Algorithm.name, inverse_of: nil

    field :triggers, type: String

    before_validation :verify_triggers

    before_save :format_triggers, :check_name

    def verify_triggers
      if changed_attributes.key?('triggers')
        self.trigger_evaluator = nil unless changed_attributes.key?('trigger_evaluator_id') && trigger_evaluator
      elsif changed_attributes.key?('trigger_evaluator_id')
        self.triggers = nil unless changed_attributes.key?('triggers') && triggers.present?
      end
      errors.blank?
    end

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
      if triggers
        field_triggers_apply_to?(:triggers, obj_now, obj_before)
      elsif trigger_evaluator.parameters.count == 1
        trigger_evaluator.run(obj_now).present?
      else
        trigger_evaluator.run([obj_now, obj_before]).present?
      end
    rescue Exception => ex
      Setup::SystemNotification.create(message: "Evaluating triggers for event '#{custom_title}' with id #{id}: #{ex.message}")
      false
    end

    class << self
      def lookup(obj_now, obj_before = nil)
        where(data_type: obj_now.orm_model.data_type).each do |e|
          # Check triggers
          next unless e.triggers_apply_to?(obj_now, obj_before)
          # Start flows
          Setup::Flow.where(active: true, event: e).each { |f| f.join_process(source_id: obj_now.id.to_s) }
          # Start notifications
          Setup::Notification.where(active: true, event: e).each do |n|
            record = obj_now.to_hash
            record[:id] ||= obj_now.id.to_s
            Setup::NotificationExecution.process(
              notification_id: n.id,
              data: {
                record: record,
                account: {
                  email: User.current.try(:email),
                  name: Account.current.try(:name),
                  token: Account.current.try(:token)
                },
                event_time: DateTime.now
              }
            )
          end
        end
      end
    end

    private

    def format_triggers
      if data_type.blank?
        errors.add(:data_type, "can't be blank")
      elsif triggers.present? && trigger_evaluator.present?
        errors.add(:base, 'Can not define both triggers and evaluator')
      elsif triggers.present?
        format_triggers_on(:triggers, true)
      elsif trigger_evaluator.present?
        unless trigger_evaluator.parameters.count == 2 || trigger_evaluator.parameters.count == 1
          errors.add(:trigger_evaluator, 'should receive one or two paramters')
        end
      else
        errors.add(:base, 'Triggers or evaluator missing')
      end
      errors.blank?
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
