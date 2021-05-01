class ScriptExecution < Setup::Task

  build_in_data_type.on_origin(:admin)

  agent_field :script, :script_id

  default_origin :admin

  belongs_to :script, class_name: Script.to_s, inverse_of: nil

  def auto_description
    if (script = agent_from_msg)
      "Executing #{script.name}"
    else
      super
    end
  end

  def maximum_resumes
    Cenit.maximum_script_execution_resumes
  end

  def run(message)
    if (script = agent_from_msg)
      result = script.run(self)
      klass = Setup::BuildInDataType::SCHEMA_TYPE_MAP.keys.detect do |type|
        type && (result.class == type || result.class < type)
      end
      schema = Setup::BuildInDataType::SCHEMA_TYPE_MAP[klass]
      result =
        case result
        when Hash, Array
          JSON.pretty_generate(result)
        else
          result.to_s
        end
      attachment =
        if result.present?
          {
            filename: "#{script.name.collectionize.dasherize}_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}.txt",
            contentType: 'text/plain',
            body: result,
            metadata: { schema: schema }
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
