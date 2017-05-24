module Setup
  class SystemNotification
    include CenitScoped
    include SystemNotificationCommon
    include RailsAdmin::Models::Setup::SystemNotificationAdmin

    build_in_data_type

    deny :copy, :new, :edit, :translator_update, :import, :convert

    attachment_uploader AccountUploader

    field :type, type: Symbol, default: :error
    field :message, type: String
    belongs_to :task, class_name: Setup::Task.to_s, inverse_of: :notifications

    validates_presence_of :type, :message
    validates_inclusion_of :type, in: ->(n) { n.type_enum }

    before_save :check_notification_level, :assign_execution_thread

    def check_notification_level
      @skip_notification_level || (a = Account.current).nil? || type_enum.index(type) <= type_enum.index(a.notification_level)
    end

    def assign_execution_thread
      if (thread_token = ThreadToken.where(token: Thread.current[:task_token]).first) &&
        (task = Setup::Task.where(thread_token: thread_token).first)
        self.task = task
      end unless self.task.present?
      true
    end

    def skip_notification_level(skip)
      @skip_notification_level = skip
    end

    def type_enum
      Setup::SystemNotification.type_enum
    end

    def label
      "[#{type.to_s.capitalize}] #{message.length > 100 ? message.to(100) + '...' : message}"
    end

    def color
      Setup::SystemNotification.type_color(type)
    end

    class << self

      def new(attributes = {})
        skip = attributes.delete(:skip_notification_level)
        notification = super
        notification.skip_notification_level(skip)
        notification
      end

      def type_enum
        [:error, :warning, :notice, :info]
      end

      def type_color(type)
        case type
        when :info
          'green'
        when :notice
          'blue'
        when :warning
          'orange'
        else
          'red'
        end
      end

      def dashboard_related(account = Account.current)
        counters = Hash.new { |h, k| h[k] = 0 }
        if account
          scope =
            if (from_date = account.notifications_listed_at)
              Setup::SystemNotification.where(:created_at.gte => from_date)
            else
              Setup::SystemNotification.all
            end
          total_count = 0
          Setup::SystemNotification.type_enum.each do |type|
            if (count = scope.where(type: type).count) > 0
              total_count += count
              counters[Setup::SystemNotification.type_color(type)] = count
            end
          end
          counters[:total] = total_count
        end
        counters
      end
      
    end

  end
end
