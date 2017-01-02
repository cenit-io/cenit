module Setup
  class TaskExecution
    include CenitScoped
    include Setup::AttachmentUploader
    include RailsAdmin::Models::Setup::TaskExecutionAdmin

    build_in_data_type

    deny :copy, :new, :translator_update, :import, :convert, :send_to_flow

    belongs_to :task, class_name: Setup::Task.to_s, inverse_of: :executions

    field :status, type: Symbol, default: :pending
    field :started_at, type: Time
    field :completed_at, type: Time

    default_scope -> { desc(:created_at) }

    def label
      (task && task.to_s) || "#{self.class.to_s.split('::').last.to_title} ##{id}"
    end

    def start(options)
      update status: :running,
             started_at: options[:time] || Time.now
    end

    def finish(options)
      status = options[:status] || :completed
      if Setup::Task::RUNNING_STATUS.include?(status)
        status = :completed
      end
      update status: status,
             completed_at: options[:time] || Time.now
    end

    def time_span
      if (start = started_at)
        (completed_at || Time.now) - start
      else
        0
      end
    end
  end
end
