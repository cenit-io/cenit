module Setup
  class Submission < Setup::Task

    build_in_data_type

    deny :copy, :new, :edit, :translator_update, :import, :convert, :delete_all

    belongs_to :webhook, class_name: Setup::Webhook.to_s, inverse_of: nil
    belongs_to :authorization, class_name: Setup::Authorization.to_s, inverse_of: nil
    belongs_to :connection, class_name: Setup::Connection.to_s, inverse_of: nil

    before_save do
      self.webhook = Setup::Webhook.where(id: message['webhook_id']).first
      self.authorization = Setup::Authorization.where(id: message['authorization_id']).first
      self.connection = Setup::Connection.where(id: message['connection_id']).first
    end

    def run(message)
      if (webhook = Setup::Webhook.where(id: (webhook_id = message[:webhook_id])).first)
        if (connection = Setup::Connection.where(id: (connection_id = message[:connection_id])).first)
          unless (auth = Setup::Authorization.where(id: (auth_id = message[:authorization_id])).first)
            notify(message: "Authorization with id #{auth_id} not found", type: :warning)
          end
          webhook.with(connection).and(auth).submit message[:body],
                                                    headers: message[:headers],
                                                    parameters: message[:parameters],
                                                    template_parameters: message[:template_parameters],
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
