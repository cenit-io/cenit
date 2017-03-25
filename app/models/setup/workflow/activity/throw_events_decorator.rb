module Setup
  class Workflow
    Activity.class_eval do

      register :throw_smtp_message => {
        :type => :event,
        :inbound_transitions => 1,
        :outbound_transitions => 1
      }

      register :throw_http_message => {
        :type => :event,
        :inbound_transitions => 1,
        :outbound_transitions => 1
      }

    end
  end
end
