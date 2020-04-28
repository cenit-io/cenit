class ScriptExecution < Setup::Task
  include RailsAdmin::Models::ScriptExecutionAdmin

  agent_field :script

  default_origin :admin

  belongs_to :script, class_name: Script.to_s, inverse_of: nil

  before_save do
    self.script = Script.where(id: message['script_id']).first
  end

  def maximum_resumes
    Cenit.maximum_script_execution_resumes
  end

  def run(message)
    if (script = Script.where(id: (script_id = message[:script_id])).first)
      result =
        case result = script.run(self)
        when Hash, Array
          JSON.pretty_generate(result)
        else
          result.to_s
        end
      attachment =
        if result.present?
          {
            filename: "#{script.name.collectionize}_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}.txt",
            contentType: 'text/plain',
            body: result
          }
        else
          nil
        end
      current_execution.attach(attachment)
      notify(message: "'#{script.name}' result" + (result.present? ? '' : ' was empty'),
             type: :notice,
             attachment: attachment,
             skip_notification_level: message[:skip_notification_level])
    else
      fail "Script with id #{script_id} not found"
    end
  end
end
