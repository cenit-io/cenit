module AccountScoped
  extend ActiveSupport::Concern
  included do
    store_in client: Proc.new {
      name = 'dhbahr-test' # TODO: get actual DB_NAME from Account

      clients = {}

      unless Mongoid::Clients.clients.has_key? name
        uri = 'mongodb://localhost:27018/dhbahr_cenit_dev' # TODO: get actual DB_URI from Account

        clients = Mongoid::Config.clients
        clients[name] = {uri: uri}

        Mongoid::Config.load_configuration({options: {}, clients: clients})
      end

      name
    }
    # store_in collection: Proc.new { Account.tenant_collection_name(to_s) }
  end
end
