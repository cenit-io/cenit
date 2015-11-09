module Setup
  class Translation < Setup::Task

    BuildInDataType.regist(self)

    Setup::Models.exclude_actions_for self, :new, :edit, :translator_update, :import, :convert, :delete_all

    belongs_to :translator, class_name: Setup::Translator.to_s, inverse_of: nil

    before_save do
      self.translator = Setup::Translator.where(id: message['translator_id']).first if translator.blank?
    end

    def run(message)
      if translator = Setup::Translator.where(id: translator_id = message[:translator_id]).first
        send('translate_' + translator.type.to_s.downcase, message)
      else
        fail "Translator with id #{translator_id} not found"
      end
    end

    def finish_attachment
      @attachment
    end

    protected

    def translate_import(message)
      translator.run(target_data_type: data_type_from(message), data: message[:data])
    end

    def translate_export(message)
      if (result = translator.run(object_ids: object_ids_from(message), source_data_type: data_type_from(message))) &&
        Cenit::Utility.json_object?(result)
        file_name = "#{data_type.title.underscore}_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}"
        file_name += ".#{translator.file_extension}" if translator.file_extension.present?
        @attachment =
          {
            filename: file_name,
            contentType: translator.mime_type || 'application/octet-stream',
            body: case result
                  when Hash, Array
                    JSON.pretty_generate(result)
                  else
                    result.to_s
                  end
          }
      end
    end

    def translate_update(message)
      simple_translate(message)
    end

    def translate_conversion(message)
      simple_translate(message)
    end

    def simple_translate(message)
      objects = objects_from(message)
      if task = message[:task]
        objects_count = objects.count
      end
      processed = 0.0
      objects.each do |object|
        translator.run(object: object)
        if task
          processed += 1
          task.progress = processed / objects_count * 100
          task.save
        end
      end
    end

    private

    def object_ids_from(message)
      message[:object_ids] || message[:bulk_ids]
    end

    def objects_from(message)
      model = data_type_from(message).records_model
      if object_ids = object_ids_from(message)
        model.any_in(id: object_ids)
      else
        model.all
      end
    end

    attr_reader :data_type

    def data_type_from(message)
      @data_type =
        if data_type_id = message['data_type_id']
          Setup::BuildInDataType.build_ins[data_type_id] || Setup::DataType.where(id: data_type_id).first ||
            fail("Data type with id #{data_type_id} not found")
        else
          fail 'Invalid message: data type ID is missing'
        end
    end
  end
end
