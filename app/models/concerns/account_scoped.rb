module AccountScoped
  extend ActiveSupport::Concern

  include Cenit::MultiTenancy::Scoped

  included do
    store_in client: Proc.new {
      name = (Account.current && Account.current.meta['db_name']) || 'default'

      clients = Mongoid.clients
      unless clients.has_key? name
        clients[name] = { uri: Account.current.meta['db_uri'] }
        Mongoid::Config.load_configuration({ options: {}, clients: clients })
      end

      name
    }
  end
end
