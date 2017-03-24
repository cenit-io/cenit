module Setup
  class Workflow
    include CrossOriginShared
    include RailsAdmin::Models::Setup::WorkflowAdmin

    field :name, type: String
    field :description, type: String
    field :valid_from, type: DateTime
    field :valid_to, type: DateTime
    field :status, type: Symbol

    has_many :activities, :class_name => Setup::WorkflowActivity.name, :inverse_of => :workflow

    accepts_nested_attributes_for :activities, :allow_destroy => true

    after_create :create_default_activities

    validate :validate_status

    def transitions
      activities.collect { |a| a.transitions }.flatten
    end

    def passable_activities
      activities.not_in(:type => WorkflowActivity.start_event_types)
    end

    def activities_with_available_inbounds
      activities.select { |a| a.has_available_inbounds? }
    end

    def status_enum
      [
        ['Under construction', :under_construction],
        ['Unavailable', :unavailable],
        ['Active', :active]
      ]
    end

    private

    def create_default_activities
      e_start = WorkflowActivity.new(:name => 'init', :type => :start_event)
      e_end = WorkflowActivity.new(:name => 'finish', :type => :end_event)
      e_start.transitions << WorkflowTransition.new(:to_activity => e_end, :is_default_transition => true)

      activities << e_start
      activities << e_end
      save
    end

    def validate_status
      if new_record? and status != :under_construction
        errors.add(:status, I18n.t('admin.form.workflow.errors.under_construction_status'))
      end

      if status == :active && !is_valid_design?
        errors.add(:status, I18n.t('admin.form.workflow.errors.invalid_design'))
      end
    end

    def is_valid_design?
      design_errors = false

      # Check presence of starting events.
      start_events = activities.in(:type => WorkflowActivity.start_event_types)
      unless start_events.exists?
        errors.add(:this_workflow, I18n.t('admin.form.workflow.errors.do_not_have_start_event'))
        design_errors = true
      end

      # Check presence of ending events.
      end_events = activities.in(:type => WorkflowActivity.end_event_types)
      unless end_events.exists?
        errors.add(:this_workflow, I18n.t('admin.form.workflow.errors.do_not_have_end_event'))
        design_errors = true
      end

      # Check activities without inbound transitions.
      accessible = start_events.to_a
      accessible.each { |aa| aa.next_activities.each { |na| accessible << na unless accessible.include?(na) } }
      inaccessible = activities.to_a - accessible
      inaccessible.each do |a|
        errors.add(:activity, I18n.t('admin.form.workflow.errors.unreachable_activity', :name => a.name))
      end
      design_errors ||= inaccessible.any?

      # TODO: Implement other design validations.

      !design_errors
    end
  end
end
