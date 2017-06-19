module Setup
  class FlowExecution < Setup::Task
    include RailsAdmin::Models::Setup::FlowExecutionAdmin

    agent_field :flow

    build_in_data_type

    deny :copy, :new, :edit, :translator_update, :import, :convert, :delete_all

    belongs_to :flow, class_name: Setup::Flow.to_s, inverse_of: nil

    before_save do
      self.flow = Setup::Flow.where(id: message['flow_id']).first
    end

    def sources
      (flow && flow.sources(message)) || []
    end

    def run(message)
      if (flow = Setup::Flow.where(id: (flow_id = message[:flow_id])).first)
        if flow.active
          flow.translate(message.merge(task: self)) { |notification_data| notify(notification_data) }
        else
          fail Setup::Task::Broken, "Flow '#{flow.custom_title}' is not active and can not be processed"
        end
      else
        fail "Flow with id #{flow_id} not found"
      end
    end

  end
end
