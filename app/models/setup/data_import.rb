module Setup
  class DataImport < Setup::Task
    include Setup::TranslationCommon
    include Setup::DataUploader

    build_in_data_type

    deny :copy, :new, :edit, :translator_update, :import, :convert, :delete_all

    protected

    def translate_import(message)
      translator.run(target_data_type: data_type_from(message), data: data.read)
    end

  end
end
