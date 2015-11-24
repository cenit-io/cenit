module Setup
  class FlowExecution < Setup::Task

    BuildInDataType.regist(self)

    Setup::Models.exclude_actions_for self, :new, :edit, :translator_update, :import, :convert, :delete_all

    belongs_to :flow, class_name: Setup::Flow.to_s, inverse_of: nil

    before_save do
      self.flow = Setup::Flow.where(id: message['flow_id']).first if flow.blank?
    end

    def run(message)
      if flow = Setup::Flow.where(id: flow_id = message[:flow_id]).first
        if flow.active
          flow.translate(message.merge(task: self)) { |notification_attributes| notify(notification_attributes) }
        else
          fail Setup::Task::Broken, "Flow '#{flow.custom_title}' is not active and can not be processed"
        end
      else
        fail "Flow with id #{flow_id} not found"
      end
    end
  end
end
