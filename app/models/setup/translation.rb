module Setup
  class Translation < Setup::Task
    include Setup::TranslationCommon

    BuildInDataType.regist(self)

    Setup::Models.exclude_actions_for self, :new, :edit, :translator_update, :import, :convert, :delete_all

    protected

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
  end
end
