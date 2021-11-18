module Setup
  class SystemNotification
    include CenitScoped
    include SystemNotificationCommon
    include RailsAdmin::Models::Setup::SystemNotificationAdmin

    build_in_data_type.including(:task)

    deny :copy, :new, :edit, :translator_update, :import, :convert

    attachment_uploader

    field :type, type: Symbol, default: :error
    field :message, type: String
    belongs_to :task, class_name: Setup::Task.to_s, inverse_of: :notifications

    validates_presence_of :type, :message
    validates_inclusion_of :type, in: ->(n) { n.type_enum }

    before_save :assign_execution_thread

    after_save :process_old_notifications if Cenit.process_old_notifications == :automatic

    def process_old_notifications
      self.class.process_old_notifications(type)
    end

    def save(*args, &block)
      check_notification_level && super
    end

    def check_notification_level
      @skip_notification_level || (
        (a = Account.current) && type_enum.index(type) <= type_enum.index(a.notification_level)
      )
    end

    def assign_execution_thread
      self.task = Setup::Task.current unless self.task.present?
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
            if (count = scope.where(type: type).count).positive?
              total_count += count
              counters[Setup::SystemNotification.type_color(type)] = count
            end
          end
          counters[:total] = total_count
        end
        counters
      end

      def process_old_notifications(type)
        without_default_scope do
          if (n = where(type: type).first) && (Time.now - n.created_at) > Tenant.notification_span_for(type)
            n.destroy
          end
        end
      end
    end
  end
end
