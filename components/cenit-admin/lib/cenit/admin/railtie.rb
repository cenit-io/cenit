module Cenit
  module Admin
    class Railtie < Rails::Railtie
      config.after_initialize do
        if defined? ::RailsAdmin
          ::RailsAdmin::Config.namespace_modules << Cenit::Admin
        end
      end
    end
  end
end
