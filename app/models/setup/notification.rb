module Setup
  class Notification
    include CenitScoped

    BuildInDataType.regist(self)

    Setup::Models.exclude_actions_for self, :new, :edit, :translator_update, :import, :convert


    field :type, type: Symbol, default: :error
    field :message, type: String
    mount_uploader :attachment, AccountUploader
    belongs_to :task, class_name: Setup::Task.to_s, inverse_of: :notifications


    validates_presence_of :type, :message
    validates_inclusion_of :type, in: ->(n) { n.type_enum }

    before_save :check_notification_level, :assign_execution_thread

    def check_notification_level
      @skip_notification_level || (a = Account.current).nil? || type_enum.index(type) <= type_enum.index(a.notification_level)
    end

    def assign_execution_thread
      if (thread_token = ThreadToken.where(token: Thread.current[:thread_token]).first) &&
        task = Setup::Task.where(thread_token: thread_token).first
        self.task = task
      end unless task.present?
      true
    end

    def skip_notification_level(skip)
      @skip_notification_level = skip
    end

    def type_enum
      Setup::Notification.type_enum
    end

    def label
      "[#{type.to_s.capitalize}] #{message.length > 100 ? message.to(100) + '...' : message}"
    end

    class << self
      def type_enum
        [:error, :warning, :notice, :info]
      end

      def create_with(attributes)
        attachment = attributes.delete(:attachment)
        skip = attributes.delete(:skip_notification_level)
        notification = Setup::Notification.new(attributes)
        notification.skip_notification_level(skip)
        temporary_file = nil
        if attachment && (readable = attachment[:body]).present?
          if readable.is_a?(String)
            temporary_file = Tempfile.new('file_')
            temporary_file.binmode
            temporary_file.write(readable)
            temporary_file.rewind
            readable = Cenit::Utility::Proxy.new(temporary_file, original_filename: attachment[:filename], contentType: attachment[:contentType])
          end
          notification.attachment = readable
        end
        notification.save ? notification : nil
      ensure
        temporary_file.close if temporary_file
      end
    end
  end
end
