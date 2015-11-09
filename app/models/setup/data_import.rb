module Setup
  class DataImport < Setup::Task
    include TranslationCommon

    BuildInDataType.regist(self)

    Setup::Models.exclude_actions_for self, :new, :edit, :translator_update, :import, :convert, :delete_all

    mount_uploader :data, AccountUploader

    before_save do
      unless data.present?
        if (@readable_data = message.delete(:data)).is_a?(String)
          temporary_file = Tempfile.new('data_')
          temporary_file.binmode
          temporary_file.write(@readable_data)
          temporary_file.rewind
          @readable_data = temporary_file
        end
        self.data = File.open(@readable_data) if @readable_data
      end
    end

    after_save do
      @readable_data.try(:close) rescue true
    end

    protected

    def translate_import(message)
      translator.run(target_data_type: data_type_from(message), data: data.read)
    end

  end
end
