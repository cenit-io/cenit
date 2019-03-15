module Setup
  module DataUploader
    extend ActiveSupport::Concern

    include UploaderHelper

    included do
      mount_uploader :data, AccountUploader

      before_store do
        store(message.delete(:data), on: data) unless data.present?
      end
    end

  end
end
