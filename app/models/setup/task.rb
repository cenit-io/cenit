module Setup
  class Task
    include CenitScoped
    include ClassHierarchyAware
    include CrossOrigin::CenitDocument
    include FieldsInspection
    include RailsAdmin::Models::Setup::TaskAdmin

    origins :default, -> { ::User.current_super_admin? ? :admin : nil }

    STATUS = [:pending, :running, :failed, :completed, :retrying, :broken, :unscheduled, :paused]
    ACTIVE_STATUS = [:running, :retrying]
    NON_ACTIVE_STATUS = STATUS - ACTIVE_STATUS
    RUNNING_STATUS = ACTIVE_STATUS + [:paused]
    ALIVE_STATUS = RUNNING_STATUS + [:pending]
    NOT_RUNNING_STATUS = STATUS - RUNNING_STATUS
    FINISHED_STATUS = NOT_RUNNING_STATUS - [:pending]

    # TODO Include instead the current execution ID
    build_in_data_type.excluding(:current_execution, :thread_token).and(
      properties: {
        status: {
          enum: STATUS.collect(&:to_s)
        }
      }
    )

    deny :copy, :new, :translator_update, :import, :convert, :send_to_flow

    field :message, type: Hash, default: {}
    field :description, type: String
    field :status, type: Symbol, default: :pending
    field :progress, type: Float, default: 0
    field :attempts, type: Integer, default: 0
    field :succeded, type: Integer, default: 0
    field :retries, type: Integer, default: 0
    field :state, type: Hash, default: {}
    field :auto_retry, type: Symbol, default: -> { auto_retry_enum.first }
    field :resumes, type: Integer, default: 0

    belongs_to :current_execution, class_name: Setup::Execution.to_s, inverse_of: nil
    has_many :executions, class_name: Setup::Execution.to_s, inverse_of: :task, dependent: :destroy

    has_many :notifications, class_name: Setup::SystemNotification.to_s, inverse_of: :task, dependent: :destroy

    belongs_to :thread_token, class_name: ThreadToken.to_s, inverse_of: nil
    belongs_to :scheduler, class_name: Setup::Scheduler.to_s, inverse_of: nil

    has_and_belongs_to_many :joining_tasks, class_name: Setup::Task.to_s, inverse_of: nil

    inspect_fields :progress, :description, :state

    validates_inclusion_of :status, in: ->(t) { t.status_enum }
    validates_numericality_of :progress, greater_than_or_equal_to: 0, less_than_or_equal_to: 100
    validates_presence_of :auto_retry

    before_save do
      message.delete(:task)
      self.description = auto_description if description.blank?
      if scheduler && scheduler.origin != origin
        errors.add(:scheduler, "with incompatible origin (#{scheduler.origin}), #{origin} origin is expected")
      end
      self.progress = progress.round(1)
      errors.blank?
    end

    before_destroy { NON_ACTIVE_STATUS.include?(status) && (scheduler.nil? || scheduler.deactivated?) }

    def save(options = {})
      options[:inspect_fields] = thread_token.present? && Thread.current[:task_token] == thread_token.token
      super
    end

    def _type_enum
      classes = Setup::Task.class_hierarchy
      classes.delete(Setup::Task)
      classes.delete(::ScriptExecution)
      classes.collect(&:to_s)
    end

    def auto_retry_enum
      self.class.auto_retry_enum
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

    def running_status?
      RUNNING_STATUS.include?(status)
    end

    def running?
      running_status? &&
        thread_token.present? &&
        Thread.list.any? { |thread| thread[:task_token] == thread_token.token }
    end

    def new_execution
      self.current_execution = Setup::Execution.create(task: self)
      save
      current_execution
    end

    def queue_execution
      if current_execution && current_execution.status == :pending
        current_execution
      else
        new_execution
      end
    end

    def maximum_resumes
      Cenit.maximum_task_resumes
    end

    def execute(options = {})
      if running? || !Cenit::Locker.lock(self)
        notify(message: "Executing task ##{id} at #{Time.now} but it is already running")
      else
        thread_token.destroy if thread_token.present?
        self.thread_token = ThreadToken.create
        self.retries += 1 if status == :retrying || status == :failed
        self.current_execution = Setup::Execution.find(options[:execution_id])
        time = Time.now
        if running_status?
          self.resumes += 1
          fail Broken, "Maximum task resumes exceeded (#{resumes})" if resumes > maximum_resumes
          notify(message: "Restarting task ##{id} at #{time}", type: :notice)
        else
          self.attempts += 1
          self.progress = 0
          self.status = :running
          self.resumes = 0
          notify(type: :info, message: "Task ##{id} started at #{time}")
        end
        Thread.current[:task_token] = thread_token.token
        current_execution.start(time: time)
        before_run_ex = nil
        do_run =
          begin
            before_run
          rescue ::Exception => ex
            before_run_ex = ex
            false
          end
        if do_run
          run(message)
          time = Time.now
          if resuming_later?
            finish(:paused, "Task ##{id} paused at #{time}", :notice, time)
          else
            self.state = {}
            self.progress = 100
            finish(:completed, "Task ##{id} completed at #{time}", :info, time)
          end
        else
          if before_run_ex
            finish(:failed, before_run_ex.message, :error, time)
          else
            finish(:failed, "Task ##{id} wasn't executed!", :warning, time)
          end
        end
      end
    rescue ::Exception => ex
      time = Time.now
      if ex.is_a?(Task::Exception)
        finish(ex.status, ex.message, ex.message_type, time)
      else
        @finish_attachment =
          {
            filename: 'backtrace.txt',
            contentType: 'plain/text',
            body: "#{ex.message}\n\n#{ex.backtrace.join("\n")}"
          }
        finish(:failed, "Task ##{id} failed at #{time}: #{ex.message}", :error, time)
      end
    ensure
      reload
      if joining_tasks.present?
        joining_tasks.each(&:retry)
        joining_tasks.nullify
      end
      Cenit::Locker.unlock(self)
    end

    def run(_message)
      fail NotImplementedError
    end

    def before_run
      true
    end

    protected :before_run

    def break(message = nil)
      raise Broken.new(message)
    end

    def unschedule
      finish(:unscheduled, "Task ##{id} unscheduled at #{time = Time.now}", :warning, time)
    end

    def notify(attrs_or_exception)
      notification =
        case attrs_or_exception
        when Hash
          Setup::SystemNotification.create_with(attrs_or_exception)
        when Exception, StandardError
          Setup::SystemNotification.create_from(attrs_or_exception)
        else
          nil
        end
      if notification
        notifications << notification
        if current_execution
          current_execution.notifications << notification
        end
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

    def resuming_manually?
      @resuming_manually
    end

    def resume_manually
      resume_later
      @resuming_manually = true
    end

    def resuming_later?
      @resuming_later
    end

    def resume_later
      fail 'Resume later is already invoked for these task' if @resuming_later
      @resuming_later = true
    end

    def resume_in(interval)
      resume_later
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

    def agent_id
      (agent = self.agent) && agent.id
    end

    def agent
      send(self.class.agent_field || :itself)
    end

    def agent_model
      self.class.agent_model
    end

    class << self

      def current
        (thread_token = ThreadToken.where(token: Thread.current[:task_token]).first) &&
          Setup::Task.where(thread_token: thread_token).first
      end

      def break(message)
        if current
          raise Broken.new(message)
        else
          Tenant.notify(message: "Calling break outside task execution context (msg: #{message})", type: :warning)
        end
      end

      def auto_retry_enum
        %w(manually automatic).collect(&:to_sym)
      end

      def process(message = {}, &block)
        message[:task] = self unless (task = message[:task]).is_a?(self) || (task.is_a?(Class) && task < self)
        Cenit::Rabbit.enqueue(message, &block)
      end

      def agent_field(*args)
        if args.length.positive?
          @agent_field = args[0]
        else
          @agent_field || superclass.try(:agent_field)
        end
      end

      def agent_model
        if (field = agent_field)
          reflect_on_association(field).klass
        else
          self
        end
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

    def clear_resume
      @resuming_later = false
      self.resumes = 0
    end

    def finish(status, message, message_type, time)
      self.status = status
      thread_token.destroy if thread_token.present?
      self.thread_token = nil
      Thread.current[:task_token] = nil
      if status == :completed
        self.succeded += 1
        self.retries = 0
      elsif status == :broken
        clear_resume
      elsif status == :failed
        clear_resume
        if auto_retry == :automatic
          resume_in case retries
                    when 0
                      '5s'
                    when 1
                      '1m'
                    when 2
                      '3m'
                    when 3
                      '5m'
                    when 4
                      '10m'
                    when 5
                      '30m'
                    when 6
                      '1h'
                    else
                      '1d'
                    end
        end
      end
      notify(type: message_type, message: message, attachment: finish_attachment)
      if current_execution
        current_execution.finish(status: status, time: time)
        self.current_execution = nil
      end
    end

  end
end
