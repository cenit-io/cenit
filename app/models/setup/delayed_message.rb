module Setup
  class DelayedMessage
    include CenitUnscoped

    Setup::Models.exclude_actions_for self, :all

    Setup::BuildInDataType.regist(self)

    field :message, type: String
    field :publish_at, type: DateTime
    field :scheduler_id
    field :token, type: String

    validates_presence_of :message, :publish_at
  end
end
