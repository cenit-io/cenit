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

    def type_enum
      [:error, :warning, :notice, :info]
    end

    def label
      "[#{type.to_s.capitalize}] #{message.length > 100 ? message.to(100) + '...' : message}"
    end
  end
end
