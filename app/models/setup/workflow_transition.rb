module Setup
  class WorkflowTransition
    include CenitScoped
    include RailsAdmin::Models::Setup::WorkflowTransitionAdmin

    field :description, type: String
    field :is_default_transition, type: Boolean
    field :to_activity_id, type: String

    embedded_in :from_activity, :class_name => Setup::WorkflowActivity.name, :inverse_of => :transitions

    def to_activity
      self.from_activity ? self.from_activity.workflow.activities.where(id: self.to_activity_id).first : nil
    end

    def to_activity=(activity)
      self.to_activity_id = activity.id
    end

    def name
      "#{self.from_activity.try(:name) || '...'} => #{self.to_activity.name || '...'}"
    end

  end
end
