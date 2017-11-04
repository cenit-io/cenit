module Setup
  module SystemNotificationCommon
    extend ActiveSupport::Concern

    include Setup::AttachmentUploader

    included do
      default_scope -> { desc(:_id) }
    end

    module ClassMethods

      def create_from(exception, header = nil)
        header ||= "#{exception.class.to_s.split('::').collect(&:to_title).join('. ')}: #{exception.message}"
        create_with(message: "#{header}: #{exception.message}",
                    attachment: {
                      filename: 'backtrace.txt',
                      contentType: 'plain/text',
                      body: "class: #{exception.class}\nmessage: #{exception.message}\n#{exception.backtrace.join("\n")}"
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
