module Setup
  class Workflow
    Activity.class_eval do

      register :end_event => {
        :type => :event,
        :inbound_transitions => 1,
        :outbound_transitions => 0
      }

      register :terminate_event => {
        :type => :event,
        :inbound_transitions => 1,
        :outbound_transitions => 0
      }

      def self.end_event_types
        %w(end_event terminate_event)
      end

    end
  end
end
