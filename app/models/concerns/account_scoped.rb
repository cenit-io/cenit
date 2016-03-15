module AccountScoped
  extend ActiveSupport::Concern
  included do
    store_in client: Proc.new {
      name = Account.current.meta['db_name'] || 'default'

      clients = Mongoid.clients
      unless clients.has_key? name
        clients[name] = {uri: Account.current.meta['db_uri']}
        Mongoid::Config.load_configuration({options: {}, clients: clients})
      end

      name
    }

    store_in collection: Proc.new { Account.tenant_collection_name(to_s) }
  end
end
