module Setup
  class Submission < Setup::Task

    BuildInDataType.regist(self)

    Setup::Models.exclude_actions_for self, :new, :edit, :translator_update, :import, :convert, :delete_all

    belongs_to :webhook, class_name: Setup::Webhook.to_s, inverse_of: nil
    belongs_to :connection, class_name: Setup::Connection.to_s, inverse_of: nil

    before_save do
      self.webhook = Setup::Webhook.where(id: message['webhook_id']).first
      self.connection = Setup::Connection.where(id: message['connection_id']).first
    end

    def run(message)
      if webhook = Setup::Webhook.where(id: webhook_id = message[:webhook_id]).first
        if connection = Setup::Connection.where(id: connection_id = message[:connection_id]).first
          webhook.upon(connection).submit message[:body],
                                          parameters: message[:parameters],
                                          notify_request: true,
                                          notify_response: true
        else
          fail "Connection with id #{connection_id} not found"
        end
      else
        fail "Webhook with id #{webhook_id} not found"
      end
    end
  end
end
