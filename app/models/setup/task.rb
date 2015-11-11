module Setup
  class Task
    include CenitScoped
    include ClassHierarchyAware

    BuildInDataType.regist(self)

    Setup::Models.exclude_actions_for self, :new, :edit, :translator_update, :import, :convert, :delete_all


    field :message, type: Hash
    field :description, type: String
    field :status, type: Symbol, default: :pending
    field :progress, type: Float, default: 0
    field :retries, type: Integer, default: 0

    has_many :notifications, class_name: Setup::Notification.to_s, inverse_of: :task, dependent: :destroy

    belongs_to :thread_token, class_name: CenitToken.to_s, inverse_of: nil
    belongs_to :scheduler, class_name: Setup::Scheduler.to_s, inverse_of: nil

    validates_inclusion_of :status, in: ->(t) { t.status_enum }
    validates_numericality_of :progress, greater_than_or_equal_to: 0, less_than_or_equal_to: 100

    before_save { self.description = auto_description if description.blank? }

    def auto_description
      to_s
    end

    def to_s
      "#{self.class.to_s.split('::').last.to_title} ##{id}"
    end

    def status_enum
      [:pending, :running, :failed, :completed, :retrying, :broken]
    end

    RUNNING_STATUS = [:running, :retrying]

    def runnin_status?
      RUNNING_STATUS.include?(status)
    end

    def running?
       runnin_status? &&
        thread_token.present? &&
        Thread.list.any? { |thread| thread[:task_token] == thread_token.token }
    end

    def execute
      if running?
        notify(message: "Executing task ##{id} at #{Time.now} but it is already running")
      else
        notify(message: "Restarting task ##{id} at #{Time.now}", type: :notice) if runnin_status?
        thread_token.destroy if thread_token.present?
        self.thread_token = CenitToken.create
        Thread.current[:task_token] = thread_token.token
        notify(type: :info, message: "Task ##{id} started at #{Time.now}")
        run(message.merge(task: self))
        self.progress = 100
        finish(:completed, "Task ##{id} completed at #{Time.now}", :info)
      end
    rescue Exception => ex
      finish(:failed, "Task ##{id} failed at #{Time.now}: #{ex.message}", :error)
    end

    def run(message)
      fail NotImplementedError
    end

    def notify(attributes)
      attachment = attributes.delete(:attachment)
      notification = Setup::Notification.new(attributes)
      temporary_file = nil
      if attachment
        readable = attachment[:body]
        if readable.is_a?(String)
          temporary_file = Tempfile.new('file_')
          temporary_file.binmode
          temporary_file.write(readable)
          temporary_file.rewind
          readable = Cenit::Utility::Proxy.new(temporary_file, original_filename: attachment[:filename], contentType: attachment[:contentType])
        end
        notification.attachment = readable
      end
      if notification.save
        notifications << notification
        save
      end
      temporary_file.close if temporary_file
    end

    def can_retry?
      !running?
    end

    def retry
      if can_retry?
        self.status = :retrying
        self.retries += 1
        notify(type: :notice, message: "Task ##{id} retried at #{Time.now}")
        Cenit::Rabbit.enqueue(message.merge(task: self))
      end
    end

    def finish_attachment
      nil
    end

    class << self
      def process(message = {})
        Cenit::Rabbit.enqueue(message.merge(task: self))
      end
    end

    private

    def finish(status, message, message_type)
      self.status = status
      thread_token.destroy if thread_token.present?
      self.thread_token = nil
      Thread.current[:task_token] = nil
      notify(type: message_type, message: message, attachment: finish_attachment)
    end
  end
end
