module Setup
  module DataUploader
    extend ActiveSupport::Concern

    include UploaderHelper

    included do

      mount_uploader :data, AccountUploader

      before_store do
        unless data.present?
          store message.delete(:data), on: data
        end
      end
    end
  end
end