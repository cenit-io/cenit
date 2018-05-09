module Setup
  module DiscardEventsOption
    extend ActiveSupport::Concern

    included do
      field :discard_events, type: Boolean
    end

    def before_create(record)
      record.instance_variable_set(:@discard_event_lookup, true) if discard_events
      super
    end
  end
end
