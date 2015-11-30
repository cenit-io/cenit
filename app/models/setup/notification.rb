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

    before_save :check_notification_level

    def check_notification_level
     (a = Account.current).nil? || type_enum.index(type) <= type_enum.index(a.notification_level)
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
    end
  end
end
