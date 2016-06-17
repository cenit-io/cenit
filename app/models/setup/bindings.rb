module Setup
  module Bindings
    extend ActiveSupport::Concern

    included do
      before_save :bind_bindings
      after_destroy :clear_bindings
    end

    def bind_bindings(options = {})
      clear_foreign_keys = !options.has_key?(:clear_foreign_keys) || options[:clear_foreign_keys]
      self.class.binds.each do |metadata|
        Setup::Binding.bind(self, send(metadata.name), metadata.klass)
        # remove_attribute(metadata.foreign_key) if clear_foreign_keys TODO Uncomment after data base migration
      end
      true
    end

    def clear_bindings
      Setup::Binding.clear(self)
    end

    module ClassMethods

      def instantiate(attrs = nil, selected_fields = nil)
        doc = super
        binds.each do |metadata|
          if (id = Setup::Binding.id_for(doc, metadata.klass))
            doc.attributes[metadata.foreign_key] = id
          end
        end
        doc
      end

      def binds
        @binds ||= []
      end

      def binding_belongs_to(name, *options)
        binds << belongs_to(name, *options)
      end
    end
  end
end
