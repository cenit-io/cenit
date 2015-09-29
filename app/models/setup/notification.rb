module Setup
  class Notification
    include CenitScoped

    BuildInDataType.regist(self)

    Setup::Models.exclude_actions_for self, :new, :edit, :update


    field :message, type: String
    field :type, type: Symbol, default: :error

    validates_presence_of :message, :type
    validates_inclusion_of :type, in: ->(n) { n.type_enum }

    def type_enum
      [:error, :warning, :notice]
    end

    def label
      "[#{type.to_s.capitalize}] #{message}"
    end
  end
end
