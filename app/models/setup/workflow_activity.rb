module Setup
  class WorkflowActivity
    include CenitScoped
    include RailsAdmin::Models::Setup::WorkflowActivityAdmin

    field :name, type: String
    field :type, type: String
    field :description, type: String
    field :attrs, type: Object

    embedded_in :workflow, :class_name => Setup::Workflow.name, :inverse_of => :activities

    embeds_many :transitions, :class_name => Setup::WorkflowTransition.name, :inverse_of => :from_activity

    accepts_nested_attributes_for :transitions, :allow_destroy => true

    after_create :create_default_transitions

    # def next_activity
    #   unless self.has_multiple_outbound?
    #     transitions.first.to_activity
    #   end
    # end

    def type_enum
      self.class.types.map { |k, _| [k.to_s.humanize, k.to_s] }.to_h
    end

    def is_end_event?
      %w(end_event terminate_event).include?(self.type)
    end

    def is_start_event?
      %w(start_event).include?(self.type)
    end

    def has_multiple_outbound?
      self.class.types[self.type.to_sym][:outbound_transitions] > 1
    end

    def has_available_inbound?
      max_inbound = self.class.types[self.type.to_sym][:inbound_transitions]
      return max_inbound > 0 && max_inbound > workflow.transitions.select { |t| t.to_activity_id = self.id }.count
    end

    private

    def create_default_transitions
      unless self.is_start_event?
        self.transitions << WorkflowTransition.new
        self.save
      end
    end

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
    end
  end
end
