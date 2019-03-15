module Setup
  module ShareWithBindings
    extend ActiveSupport::Concern

    include SharedConfigurable
    include Bindings

    def configure
      super
      bind_bindings
    end

    module ClassMethods
      def binding_belongs_to(name, *options)
        r = super
        shared_configurable r.name, r.foreign_key
        r
      end

      def clear_config_for(tenant, ids)
        super
        Setup::Binding.with(tenant).clear(self, ids)
      end
    end
  end
end