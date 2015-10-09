module Setup
  class Task
    include CenitScoped

    BuildInDataType.regist(self)

    Setup::Models.exclude_actions_for self, :new, :edit, :update, :delete_all


    field :message, type: Hash
    field :description, type: String
    field :status, type: Symbol, default: :pending
    field :progress, type: Float, default: 0
    field :retries, type: Integer, default: 0

    has_many :notifications, class_name: Setup::Notification.to_s, inverse_of: :task, dependent: :destroy

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
      [:pending, :running, :failed, :completed, :retrying]
    end

    def execute
      begin
        self.status = :running
        notify(type: :notice, message: "Task ##{id} started at #{Time.now}")
        run(message.merge(task: self))
        self.progress = 100
        self.status = :completed
        notify(type: :notice, message: "Task ##{id} completed at #{Time.now}")
      rescue Exception => ex
        self.status = :failed
        notify(message: "Task ##{id} failed at #{Time.now}: #{ex.message}")
      end
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
      status == :completed || status == :failed
    end

    def retry
      if can_retry?
        self.status = :retrying
        self.retries += 1
        notify(type: :notice, message: "Task ##{id} retried at #{Time.now}")
        Cenit::Rabbit.enqueue(message.merge(task: self))
      end
    end
  end
end
