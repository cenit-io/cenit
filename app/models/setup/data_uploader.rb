module Setup
  module DataUploader
    extend ActiveSupport::Concern

    included do

      mount_uploader :data, AccountUploader

      before_save do
        unless data.present?
          if (@readable_data = message.delete(:data)).is_a?(String)
            temporary_file = Tempfile.new('data_')
            temporary_file.binmode
            temporary_file.write(@readable_data)
            temporary_file.rewind
            @readable_data =  File.open(temporary_file)
          end
          self.data = @readable_data if @readable_data
        end
      end

      after_save do
        @readable_data.try(:close) rescue true
      end
    end
  end
end