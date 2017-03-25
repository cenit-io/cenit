module Setup
  class Workflow
    Activity.class_eval do
      register :start_event => {
        :type => :event,
        :inbound_transitions => 0,
        :outbound_transitions => 1
      }

      def self.start_event_types
        %w(start_event)
      end
    end
  end
end
