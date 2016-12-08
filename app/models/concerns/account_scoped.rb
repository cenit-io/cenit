module AccountScoped
  extend ActiveSupport::Concern

  include Cenit::MultiTenancy::Scoped

  included do
    store_in client: Proc.new {
      name = (Cenit.using_accounts_dbs && Account.current && Account.current.meta['db_name']) || 'default'

      unless (clients = Mongoid.clients).has_key?(name)
        clients[name] = { uri: Account.current.meta['db_uri'] }
        Mongoid::Config.load_configuration({ options: {}, clients: clients })
      end

      name
    }
  end
end
