module Setup
  class Task
    include CenitScoped
    include ClassHierarchyAware

    BuildInDataType.regist(self)

    Setup::Models.exclude_actions_for self, :new, :translator_update, :import, :convert, :send_to_flow


    field :message, type: Hash
    field :description, type: String
    field :status, type: Symbol, default: :pending
    field :progress, type: Float, default: 0
    field :attempts, type: Integer, default: 0
    field :succeded, type: Integer, default: 0
    field :retries, type: Integer, default: 0
    field :state, type: Hash, default: {}

    has_many :notifications, class_name: Setup::Notification.to_s, inverse_of: :task, dependent: :destroy

    belongs_to :thread_token, class_name: ThreadToken.to_s, inverse_of: nil
    belongs_to :scheduler, class_name: Setup::Scheduler.to_s, inverse_of: nil

    validates_inclusion_of :status, in: ->(t) { t.status_enum }
    validates_numericality_of :progress, greater_than_or_equal_to: 0, less_than_or_equal_to: 100

    before_save { self.description = auto_description if description.blank? }

    before_destroy { NOT_RUNNING_STATUS.include?(status) }

    def auto_description
      to_s
    end

    def to_s
      "#{self.class.to_s.split('::').last.to_title} ##{id}"
    end

    def status_enum
      STATUS
    end

    def attempts_succeded
      "#{attempts}/#{succeded}"
    end

    STATUS = [:pending, :running, :failed, :completed, :retrying, :broken, :unscheduled, :paused]
    RUNNING_STATUS = [:running, :retrying, :paused]
    NOT_RUNNING_STATUS = STATUS.reject { |status| RUNNING_STATUS.include?(status) }

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
        thread_token.destroy if thread_token.present?
        self.thread_token = ThreadToken.create
        Thread.current[:task_token] = thread_token.token
        if status == :retrying
          self.retries += 1
        end
        if runnin_status?
          notify(message: "Restarting task ##{id} at #{Time.now}", type: :notice)
        else
          self.attempts += 1
          self.progress = 0
          self.status = :running
          notify(type: :info, message: "Task ##{id} started at #{Time.now}")
        end
        run(message)
        if resuming_later?
          finish(:paused, "Task ##{id} paused at #{Time.now}", :notice)
        else
          self.state = {}
          self.progress = 100
          finish(:completed, "Task ##{id} completed at #{Time.now}", :info)
        end
      end
    rescue ::Exception => ex
      if ex.is_a?(Task::Exception)
        finish(ex.status, ex.message, ex.message_type)
      else
        finish(:failed, "Task ##{id} failed at #{Time.now}: #{ex.message}", :error)
      end
    end

    def run(message)
      fail NotImplementedError
    end

    def unschedule
      finish(:unscheduled, "Task ##{id} unscheduled at #{Time.now}", :warning)
    end

    def notify(attributes)
      if notification = Setup::Notification.create_with(attributes)
        notifications << notification
      end
      save
    end

    def can_retry?
      !running?
    end

    def can_schedule?
      can_retry?
    end

    def schedule(scheduler)
      if can_schedule?
        self.scheduler = scheduler
        self.retry
      end
    end

    def retry
      if can_retry?
        self.status = (status == :failed ? :retrying : :pending)
        notify(type: :notice, message: "Task ##{id} executed at #{Time.now}")
        Cenit::Rabbit.enqueue(message.merge(task: self))
      end
    end

    def finish_attachment
      nil
    end

    def resuming_later?
      @resuming_later
    end

    def resume_in(interval)
      fail 'Resume later is already invoked for these task' if @resuming_later
      @resuming_later = true
      @resume_in =
        if interval.is_a?(Integer)
          interval
        else
          interval.to_s.to_seconds_interval
        end
    end

    def run_again
      resume_in(0)
    end

    def resume_interval
      @resume_in
    end

    class << self

      def process(message = {})
        Cenit::Rabbit.enqueue(message.merge(task: self))
      end

      def destroy_conditions
        {
          'status' => { '$in' => Setup::Task::NOT_RUNNING_STATUS },
          'scheduler_id' => { '$in' => Setup::Scheduler.where(activated: false).collect(&:id) + [nil] }
        }
      end
    end

    class Exception < ::Exception

      def initialize(msg, options = {})
        super(msg)
        @options = options || {}
      end

      def status
        @options[:status] || :failed
      end

      def message_type
        @options[:message_type] || :error
      end
    end

    class Broken < Exception
      def initialize(msg)
        super(msg, status: :broken, message_type: :warning)
      end
    end

    private

    def finish(status, message, message_type)
      self.status = status
      thread_token.destroy if thread_token.present?
      self.thread_token = nil
      Thread.current[:task_token] = nil
      if status == :completed
        self.succeded += 1
        self.retries = 0
      end
      notify(type: message_type, message: message, attachment: finish_attachment)
    end
  end
end
