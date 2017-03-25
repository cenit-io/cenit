module Setup
  class WorkflowActivity
    include CenitScoped
    include RailsAdmin::Models::Setup::WorkflowActivityAdmin

    field :name, type: String
    field :type, type: String
    field :description, type: String

    belongs_to :workflow, :class_name => Setup::Workflow.name, :inverse_of => :activities
    has_many :transitions, :class_name => Setup::WorkflowTransition.name, :inverse_of => :from_activity, :dependent => :destroy
    has_many :in_transitions, :class_name => Setup::WorkflowTransition.name, :inverse_of => :to_activity, :dependent => :destroy

    accepts_nested_attributes_for :transitions, :allow_destroy => true

    validates_uniqueness_of :type, :scope => :workflow, :if => proc { self.is_start_event? || self.is_end_event? }

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
      self.class.types[self.type.to_sym][:inbound_transitions]
    end

    def max_outbounds
      self.class.types[self.type.to_sym][:outbound_transitions]
    end

    def next_activities
      transitions.map { |t| t.to_activity }.compact
    end

    def next_activity_id
      transitions.first.try(:to_activity).try(:id)
    end

    def next_activity_id=(id)
      if has_simple_outbound? && id != next_activity_id
        self.transitions = [WorkflowTransition.new(:to_activity_id => id)]
      end
    end

    private

    class << self
      def types
        {
          :start_event => {
            :type => :event,
            :inbound_transitions => 0,
            :outbound_transitions => 1
          },
          :split_inclusive => {
            :type => :decision,
            :inbound_transitions => 1,
            :outbound_transitions => 100
          },
          :split_exclusive => {
            :type => :decision,
            :inbound_transitions => 1,
            :outbound_transitions => 100
          },
          :split_parallel => {
            :type => :decision,
            :inbound_transitions => 1,
            :outbound_transitions => 100
          },
          :join_inclusive => {
            :type => :decision,
            :inbound_transitions => 100,
            :outbound_transitions => 1
          },
          :join_exclusive => {
            :type => :decision,
            :inbound_transitions => 100,
            :outbound_transitions => 1
          },
          :join_parallel => {
            :type => :decision,
            :inbound_transitions => 100,
            :outbound_transitions => 1
          },
          :throw_smtp_message => {
            :type => :event,
            :inbound_transitions => 1,
            :outbound_transitions => 1
          },
          :throw_http_message => {
            :type => :event,
            :inbound_transitions => 1,
            :outbound_transitions => 1
          },
          :terminate_event => {
            :type => :event,
            :inbound_transitions => 1,
            :outbound_transitions => 0
          },
          :end_event => {
            :type => :event,
            :inbound_transitions => 1,
            :outbound_transitions => 0
          }
        }
      end

      def start_event_types
        %w(start_event)
      end

      def end_event_types
        %w(end_event terminate_event)
      end
    end
  end
end
