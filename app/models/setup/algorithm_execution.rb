module Setup
  class AlgorithmExecution < Setup::Task
    # = Algorithm Execution
    #
    # Task execution for an algorithm.

    agent_field :algorithm, :algorithm_id

    build_in_data_type

    belongs_to :algorithm, class_name: Setup::Algorithm.to_s, inverse_of: nil

    def auto_description
      if (alg = agent_from_msg)
        "Executing #{alg.custom_title}"
      else
        super
      end
    end

    def run(message)
      algorithm_id = message[:algorithm_id]
      if (algorithm = agent_from_msg)
        result = algorithm.run(message[:input], self).capataz_slave
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
              filename: "#{algorithm.name.collectionize}_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}.txt",
              contentType: 'text/plain',
              body: result,
              metadata: { schema: schema }
            }
          else
            nil
          end
        current_execution.attach(attachment)
        notify(message: "'#{algorithm.custom_title}' result" + (result.present? ? '' : ' was empty'),
               type: :notice,
               attachment: attachment,
               skip_notification_level: message[:skip_notification_level])
      else
        fail "Algorithm with id #{algorithm_id} not found"
      end
    end

  end
end
