module Setup
  class WorkflowTransition
    include CenitScoped
    include RailsAdmin::Models::Setup::WorkflowTransitionAdmin

    field :description, type: String
    field :is_default_transition, type: Boolean

    belongs_to :from_activity, :class_name => Setup::WorkflowActivity.name, :inverse_of => :transitions
    belongs_to :to_activity, :class_name => Setup::WorkflowActivity.name, :inverse_of => :in_transitions

    validates_uniqueness_of :to_activity, :scope => :from_activity
    validate :validate_activities

    def name
      "#{from_activity.try(:name) || '...'} => #{to_activity.try(:name) || '...'}"
    end

    private

    def validate_activities
      unless to_activity.nil?
        if from_activity == to_activity
          errors.add(:to_activity, I18n.t('admin.form.workflow_transition.errors.transition_to_self'))
        end

        if (new_record? || attribute_changed?(:to_activity)) && !to_activity.has_available_inbounds?
          errors.add(:to_activity, I18n.t('admin.form.workflow_transition.errors.inbound_overflow'))
        end
      end
    end

  end
end
