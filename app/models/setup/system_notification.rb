module Setup
  class SystemNotification
    include CenitUnscoped

    store_in collection: :setup_notifications

    BuildInDataType.regist(self)

    field :type, type: Symbol, default: :error
    field :message, type: String

    def label
      "[#{type.to_s.capitalize}] #{message.length > 100 ? message.to(100) + '...' : message}"
    end
  end
end
