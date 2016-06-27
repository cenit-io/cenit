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
        shared_configurable super.foreign_key
      end

      def clear_config_for(account, ids)
        super
        Setup::Binding.with(account).clear(self, ids)
      end
    end
  end
end