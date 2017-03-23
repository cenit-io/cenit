module Setup
  class Workflow
    include CrossOriginShared
    include RailsAdmin::Models::Setup::WorkflowAdmin

    field :name, type: String
    field :description, type: String
    field :valid_from, type: DateTime
    field :valid_to, type: DateTime
    field :active, type: Boolean

    has_many :activities, :class_name => Setup::WorkflowActivity.name, :inverse_of => :workflow

    accepts_nested_attributes_for :activities, :allow_destroy => true

    after_create :create_default_activities

    def transitions
      activities.collect { |a| a.transitions }.flatten
    end

    def passable_activities
      activities.not_in(:type => WorkflowActivity.start_event_types)
    end

    def activities_with_available_inbound
      activities.select { |a| a.has_available_inbound? }
    end

    private

    def create_default_activities
      self.activities << WorkflowActivity.new(
        :name => 'init',
        :type => :start_event
      )
      self.activities << WorkflowActivity.new(
        :name => 'finish',
        :type => :end_event
      )
      self.save
    end
  end
end
