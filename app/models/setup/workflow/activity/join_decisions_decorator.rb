module Setup
  class Workflow
    Activity.class_eval do

      register :join_inclusive => {
        :type => :decision,
        :inbound_transitions => 100,
        :outbound_transitions => 1
      }

      register :join_exclusive => {
        :type => :decision,
        :inbound_transitions => 100,
        :outbound_transitions => 1
      }

      register :join_parallel => {
        :type => :decision,
        :inbound_transitions => 100,
        :outbound_transitions => 1
      }

    end
  end
end
