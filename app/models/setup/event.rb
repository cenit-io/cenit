module Setup
  class Event
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Trackable

    field :name, type: String
    field :last_trigger_timestamps, type: DateTime

    def data_type
      nil
    end
  end
end
