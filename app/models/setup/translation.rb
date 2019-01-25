module Setup
  class Translation < Setup::Task
    include Setup::TranslationCommon
    include ::RailsAdmin::Models::Setup::TranslationAdmin

    agent_field :translator

    build_in_data_type

    deny :copy, :new, :edit, :translator_update, :import, :convert, :delete_all

    protected

    def translate_export(message)
      result = translator.run(object_ids: object_ids_from(message),
                              source_data_type: data_type_from(message),
                              task: self,
                              options: message[:options].deep_dup.with_indifferent_access)
      return unless result && Cenit::Utility.json_object?(result)
      attachment = Setup::Translation.attachment_for(data_type, translator, result)
      current_execution.attach(attachment)
      notify(type: :notice,
             message: "'#{translator.custom_title}' export result",
             attachment: attachment,
             skip_notification_level: message[:skip_notification_level])
    end

    def translate_update(message)
      simple_translate(message)
    end

    def translate_conversion(message)
      simple_translate(message)
    end

    def simple_translate(message)
      if translator.try(:source_handler)
        translator.run(object_ids: object_ids_from(message),
                       data_type: data_type_from(message),
                       task: self,
                       options: message[:options].deep_dup.with_indifferent_access)
      else
        objects = objects_from(message)
        objects_count = objects.count
        processed = 0.0
        objects.each do |object|
          translator.run(object: object,
                         task: self,
                         data_type: data_type_from(message),
                         options: message[:options].deep_dup.with_indifferent_access)
          processed += 1
          self.progress = processed / objects_count * 100
          save
        end
      end
    end

    class << self

      def attachment_for(data_type, translator, result)
        title = (data_type && data_type.title) || translator.name
        file_name = "#{title.collectionize}_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}"
        file_name += ".#{translator.file_extension}" if translator.file_extension.present?
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

  end
end
