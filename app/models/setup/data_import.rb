module Setup
  class DataImport < Setup::Task
    include Setup::TranslationCommon
    include Setup::DataUploader

    BuildInDataType.regist(self)

    Setup::Models.exclude_actions_for self, :new, :edit, :translator_update, :import, :convert, :delete_all

    protected

    def translate_import(message)
      translator.run(target_data_type: data_type_from(message), data: data.read)
    end

  end
end
