module Setup
  module NotificationCommon
    extend ActiveSupport::Concern

    include Setup::AttachmentUploader

    included do
      default_scope -> { desc(:created_at) }
    end

    module ClassMethods

      def create_from(exception)
        create_with(message: exception.message,
                    attachment: {
                      filename: 'backtrace.txt',
                      contentType: 'plain/text',
                      body: exception.backtrace.join("\n")
                    })
      end

      def create_with(attributes)
        attachment = attributes.delete(:attachment)
        notification = new(attributes)
        temporary_file = nil
        if attachment && attachment[:body].present?
          notification.attach(attachment)
        end
        notification.save ? notification : nil
      ensure
        temporary_file.close if temporary_file
      end
    end
  end
end
