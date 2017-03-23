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
      "#{self.from_activity.try(:name) || '...'} => #{self.to_activity.try(:name) || '...'}"
    end

    private

    def validate_activities
      errors.add(:team_code, I18n.t("workflow.transition.erros.cicle")) if self.from_activity == self.to_activity
    end

  end
end
