module Setup
  module DataUploader
    extend ActiveSupport::Concern

    include UploaderHelper

    included do
      mount_uploader :data, AccountUploader

      before_store do
        msg_data = message.delete(:data)
        if msg_data.is_a?(BSON::Binary)
          msg_data = msg_data.data
        end
        store(msg_data, on: data) unless data.present?
      end
    end
  end
end
