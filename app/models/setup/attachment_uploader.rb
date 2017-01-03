module Setup
  module AttachmentUploader
    extend ActiveSupport::Concern
    include Setup::UploaderHelper

    included do
      mount_uploader :attachment, AccountUploader
    end

    def attach(attachment)
      body = nil
      store_options = { on: self.attachment }
      if attachment.is_a?(Hash)
        attachment.each do |key, value|
          if key.to_s == 'body'
            body = value
          else
            store_options[key] = value
          end
        end
      end
      body ||= attachment
      store(body, store_options)
    end
  end
end
