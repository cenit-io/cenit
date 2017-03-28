module Setup
  class Workflow
    include CrossOriginShared
    include RailsAdmin::Models::Setup::WorkflowAdmin

    field :name, type: String
    field :description, type: String
    field :valid_from, type: DateTime
    field :valid_to, type: DateTime
    field :status, type: Symbol, :default => :under_construction

    has_many :activities, :class_name => Activity.name, :inverse_of => :workflow

    accepts_nested_attributes_for :activities, :allow_destroy => true

    validate :validate_status

    after_create :create_default_activities
    after_save :organize_activities

    def transitions
      activities.collect { |a| a.transitions }.flatten
    end

    def passable_activities
      activities.not_in(:type => Activity.start_event_types)
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

    def organize_activities
      organized = {}
      items = activities.to_a
      items.each { |a| a.x_coordinate = a.y_coordinate = -1 }
      height = Activity::ICON_COORD[:h] + Activity::ICON_COORD[:m]

      # Organize accessible activities.
      start_events = items.select { |a| Activity.start_event_types.include?(a.type) }
      candidates = start_events.map { |a| { previous: false, activity: a } }

      2.times.each do
        candidates.each do |c|
          width = c[:activity].setting[:width] || Activity::ICON_COORD[:w]

          c[:activity].x_coordinate = c[:previous] ? c[:previous].x_coordinate + width : 0
          c[:activity].y_coordinate = c[:previous] ? c[:previous].y_coordinate : 0

          while (items.select { |a| c[:activity].is_overlap?(a) }.any?) do
            c[:activity].y_coordinate += height
          end

          organized[c[:activity].id] = true

          n_ids = c[:activity].next_activities.map(&:id)
          items.select { |a| !organized[a.id] && n_ids.include?(a.id) }.each do |a|
            candidates << { previous: c[:activity], activity: a }
          end
        end

        # Organize inaccessible activities.
        inaccessibles = items.select { |a| a.in_transitions.count == 0 }
        candidates = inaccessibles.map { |a| { previous: false, activity: a } }
      end

      # Save activities
      items.each { |a| a.save }
    end

    def to_svg
      items = activities.to_a
      vbw = items.map(&:x_coordinate).max + Activity::ICON_COORD[:w] + Activity::ICON_COORD[:m]
      vbh = items.map(&:y_coordinate).max + Activity::ICON_COORD[:h] + Activity::ICON_COORD[:m]
      dx = Activity::ICON_COORD[:dx]
      dy = Activity::ICON_COORD[:dy]

      svg = "<svg viewBox='0 0 #{vbw} #{vbh}' width='100%' height='100%' xmlns:xlink='http://www.w3.org/1999/xlink' xmlns='http://www.w3.org/2000/svg' xmlns:se='http://svg-edit.googlecode.com'>"
      svg << "<g transform='scale(0.5),translate(#{dx},#{dy})' style='stroke: black; fill: #FFFFFF;'>"
      svg << "<title>#{name}</title>"
      items.each do |activity|
        svg << activity.to_svg.to_s
        activity.transitions.each do |transition|
          svg << transition.to_svg.to_s
        end
      end
      svg << "</g>"
      svg << "</svg>"
    end

    def is_read_only?
      status != :under_construction
    end

    private

    def create_default_activities
      e_start = Activity.new(:name => 'init', :type => :start_event)
      e_end = Activity.new(:name => 'finish', :type => :end_event)
      e_start.transitions << Transition.new(:to_activity => e_end, :is_default_transition => true)

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
      start_events = activities.in(:type => Activity.start_event_types)
      unless start_events.exists?
        errors.add(:this_workflow, I18n.t('admin.form.workflow.errors.do_not_have_start_event'))
        design_errors = true
      end

      # Check presence of ending events.
      end_events = activities.in(:type => Activity.end_event_types)
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
