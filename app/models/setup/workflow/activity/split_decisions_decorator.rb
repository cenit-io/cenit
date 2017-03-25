module Setup
  class Workflow
    Activity.class_eval do

      register :split_inclusive => {
        :type => :decision,
        :inbound_transitions => 1,
        :outbound_transitions => 100
      }

      register :split_exclusive => {
        :type => :decision,
        :inbound_transitions => 1,
        :outbound_transitions => 100
      }

      register :split_parallel => {
        :type => :decision,
        :inbound_transitions => 1,
        :outbound_transitions => 100
      }

    end
  end
end
