module AccountScoped
  extend ActiveSupport::Concern

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

    store_in collection: Proc.new { Account.tenant_collection_name(to_s) }
  end

  module ClassMethods
    def with(options)
      if (account = options).is_a?(Account) ||
        (options.is_a?(Hash) && options.has_key?(:account) && ((account = options.delete(:account)) || true))
        options = { collection: Account.tenant_collection_name(self, account: account) }
      end
      super
    end
  end
end
