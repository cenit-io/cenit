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

    rails_admin do
      edit do
        field :name
        end

      show do
        field :name
        field :last_trigger_timestamps

        field :_id
        field :created_at
        field :creator
        field :updated_at
        field :updater
      end

      fields :name, :last_trigger_timestamps
    end
  end
end
