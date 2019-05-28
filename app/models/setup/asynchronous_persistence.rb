module Setup
  class AsynchronousPersistence < Setup::Task
    build_in_data_type

    def target_model_name
      message[:model_name] || message['model_name']
    end

    def target_model
      model_name = target_model_name
      model =
        begin
          model_name.constantize
        rescue
          nil
        end
      unless model
        if model_name.start_with?('Dt') && (data_type = Setup::DataType.where(id: model_name.from(2)).first)
          model = data_type.records_model
        end
      end
      model
    end

    def target
      (model = target_model) &&
        model.where(id: message[:id] || message['id']).first
    end

    def run(message)
      if (model = target_model)
        unless (record = model.where(id: message[:id]).first)
          record = model.new
        end
        record.assign_attributes(message[:attributes])
        unless (options = message[:options]).is_a?(Hash)
          options = {}
        end
        if record.save(options)
          message[:id] = record.id
        else
          notify(type: :error, message: "Persistence failed: #{record.errors.full_messages.to_sentence}")
        end
      else
        fail "Can not determine records model from name '#{target_model_name}'"
      end
    end

  end
end
