module Setup
  class Workflow
    class Activity
      include CenitScoped
      include RailsAdmin::Models::Setup::WorkflowActivityAdmin

      ICON_COORD = { dx: 100, dy: 50, mx: 100, my: 100, w: 100, h: 50, m: 10 }

      field :name, type: String
      field :type, type: Symbol
      field :description, type: String
      field :x_coordinate, type: Integer, default: 0
      field :y_coordinate, type: Integer, default: 0

      belongs_to :workflow, :class_name => Setup::Workflow.name, :inverse_of => :activities
      has_many :transitions, :class_name => Setup::Workflow::Transition.name, :inverse_of => :from_activity, :dependent => :destroy
      has_many :in_transitions, :class_name => Setup::Workflow::Transition.name, :inverse_of => :to_activity, :dependent => :destroy

      accepts_nested_attributes_for :transitions, :allow_destroy => true

      validate :validate_type

      before_save :set_name

      default_scope -> { asc(:x_coordinate, :y_coordinate) }

      def type_enum
        self.class.types.map { |k, _| [k.to_s.humanize, k.to_s] }.to_h
      end

      def is_end_event?
        self.class.end_event_types.include?(self.type)
      end

      def is_start_event?
        self.class.start_event_types.include?(self.type)
      end

      def has_multiple_outbounds?
        max_outbounds > 1
      end

      def has_simple_outbound?
        max_outbounds == 1
      end

      def has_available_inbounds?
        max = max_inbounds
        return max > 0 && max > in_transitions.count
      end

      def max_inbounds
        self.setting[:inbound_transitions]
      end

      def max_outbounds
        self.setting[:outbound_transitions]
      end

      def next_activities
        transitions.map { |t| t.to_activity }.compact
      end

      def next_activity_id
        transitions.first.try(:to_activity).try(:id)
      end

      def next_activity_id=(id)
        if has_simple_outbound? && id != next_activity_id
          self.transitions = id.to_s.empty? ? [] : [Workflow::Transition.new(:to_activity_id => id)]
        end
      end

      def setting
        self.class.types[self.type]
      end

      private

      def set_name
        if new_record?
          prefix = self.type.to_s.split('_').map(&:first).join.upcase
          self.name = "#{prefix}#{self.class.last_index(workflow, true)}"
        end
      end

      def validate_type
        if type == :start_event && workflow.activities.where(:type => :start_event, :id => {'$ne' => id}).exists?
          errors.add(:type, I18n.t('admin.form.activity.errors.start_event_already_exists'))
          errors.add(:type, I18n.t('admin.form.activity.errors.start_event_already_exists_alternative'))
        end

        if type == :end_event && workflow.activities.where(:type => :end_event, :id => {'$ne' => id}).exists?
          errors.add(:type, I18n.t('admin.form.activity.errors.end_event_already_exists'))
          errors.add(:type, I18n.t('admin.form.activity.errors.end_event_already_exists_alternative'))
        end
      end

      class << self
        def types
          @type
        end

        def last_index(workflow, increase=false)
          @last_index ||= {}
          @last_index[workflow.id]
          @last_index[workflow.id] ||= begin
            workflow.activities.select { |a| !a.new_record? }.map { |a| a.name.gsub(/[^\d]+/, '').to_i }.sort.last || 0
          end
          @last_index[workflow.id] += 1 if increase
          @last_index[workflow.id]
        end

        def register(type, setting)
          @type ||= {}
          [type].flatten.each { |t| @type[t] = setting }
        end
      end
    end
  end
end
