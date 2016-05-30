module Setup
  class Task
    include CenitScoped
    include ClassHierarchyAware
    include CrossOrigin::Document

    origins -> { Account.current_super_admin? ? :admin : nil }

    BuildInDataType.regist(self)

    Setup::Models.exclude_actions_for self, :copy, :new, :translator_update, :import, :convert, :send_to_flow

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

    has_and_belongs_to_many :joining_tasks, class_name: Setup::Task.to_s, inverse_of: nil


    validates_inclusion_of :status, in: ->(t) { t.status_enum }
    validates_numericality_of :progress, greater_than_or_equal_to: 0, less_than_or_equal_to: 100

    before_save do
      message.delete(:task)
      self.description = auto_description if description.blank?
      if scheduler && scheduler.origin != origin
        errors.add(:scheduler, "with incompatible origin (#{scheduler.origin}), #{origin} origin is expected")
      end
      errors.blank?
    end

    before_destroy { NOT_RUNNING_STATUS.include?(status) }

    def _type_enum
      classes = Setup::Task.class_hierarchy
      classes.delete(Setup::Task)
      classes.delete(::ScriptExecution)
      classes.collect(&:to_s)
    end

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
      if running? || !Cenit::Locker.lock(self)
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
        @finish_attachment =
          {
            filename: 'backtrace.txt',
            contentType: 'plain/text',
            body: ex.backtrace.join("\n")
          }
        finish(:failed, "Task ##{id} failed at #{Time.now}: #{ex.message}", :error)
      end
    ensure
      reload
      if joining_tasks.present?
        joining_tasks.each { |task| task.retry }
        joining_tasks.nullify
      end
      Cenit::Locker.unlock(self)
    end

    def run(message)
      fail NotImplementedError
    end

    def unschedule
      finish(:unscheduled, "Task ##{id} unscheduled at #{Time.now}", :warning)
    end

    def notify(attrs_or_exception)
      notification =
        case attrs_or_exception
        when Hash
          Setup::Notification.create_with(attrs_or_exception)
        when Exception, StandardError
          Setup::Notification.create_from(attrs_or_exception)
        else
          nil
        end
      notifications << notification if notification
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
        self.retry(action: 'scheduled')
      end
    end

    def retry(options = {})
      if can_retry?
        self.status = (status == :failed ? :retrying : :pending)
        notify(type: :notice, message: "Task ##{id} #{options[:action] || 'executed'} at #{Time.now}")
        Cenit::Rabbit.enqueue(message.merge(task: self))
      end
    end

    attr_reader :finish_attachment

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

    def join(task)
      task.joining_tasks << self
      @joining = true
    end

    def joining?
      @joining.to_b
    end

    class << self

      def process(message = {}, &block)
        Cenit::Rabbit.enqueue(message.merge(task: self), &block)
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
