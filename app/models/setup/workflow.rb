module Setup
  class Workflow
    include CrossOriginShared
    include RailsAdmin::Models::Setup::WorkflowAdmin

    field :name, type: String
    field :description, type: String
    field :valid_from, type: DateTime
    field :valid_to, type: DateTime
    field :status, type: Symbol, :default => :under_construction

    has_many :activities, :class_name => Setup::Workflow::Activity.name, :inverse_of => :workflow

    accepts_nested_attributes_for :activities, :allow_destroy => true

    validate :validate_status

    after_create :create_default_activities
    after_save :organize_activities

    def transitions
      activities.collect { |a| a.transitions }.flatten
    end

    def passable_activities
      activities.not_in(:type => Workflow::Activity.start_event_types)
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

    def organize_activities()
      # Organize accessible activities.
      start_events = activities.in(:type => Workflow::Activity.start_event_types)
      start_events.to_a.each do |activity|
        activity.x_oordinate = 0
        activity.y_oordinate = 0
        activity.save
        activity.organize_activities
      end

      # Organize inaccessible activities.
      accessible = start_events.to_a
      accessible.each { |aa| aa.next_activities.each { |na| accessible << na unless accessible.include?(na) } }
      inaccessible = activities.to_a - accessible
      inaccessible.each do |activity|
        activity.x_oordinate = 0
        activity.y_oordinate = 0
        activity.save
        activity.organize_activities
      end
    end

    private

    def create_default_activities
      e_start = Workflow::Activity.new(:name => 'init', :type => :start_event)
      e_end = Workflow::Activity.new(:name => 'finish', :type => :end_event)
      e_start.transitions << Workflow::Transition.new(:to_activity => e_end, :is_default_transition => true)

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
      start_events = activities.in(:type => Workflow::Activity.start_event_types)
      unless start_events.exists?
        errors.add(:this_workflow, I18n.t('admin.form.workflow.errors.do_not_have_start_event'))
        design_errors = true
      end

      # Check presence of ending events.
      end_events = activities.in(:type => Workflow::Activity.end_event_types)
      unless end_events.exists?
        errors.add(:this_workflow, I18n.t('admin.form.workflow.errors.do_not_have_end_event'))
        design_errors = true
      end

      # Check activities without inbound transitions.
      accessible = start_events.to_a
      accessible.each { |aa| aa.next_activities.each { |na| accessible << na unless accessible.include?(na) } }
      inaccessible = activities.to_a - accessible
      inaccessible.each do |a|
        errors.add(:activities, I18n.t('admin.form.workflow.errors.unreachable_activity', :name => a.name))
      end
      design_errors ||= inaccessible.any?

      # TODO: Implement other design validations.

      !design_errors
    end
  end
end
