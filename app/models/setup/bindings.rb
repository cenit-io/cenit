module Setup
  module Bindings
    extend ActiveSupport::Concern

    included do
      after_destroy :clear_bindings
    end

    def bind_bindings
      self.class.binds.each do |metadata|
        Setup::Binding.bind(self, send(metadata.name), metadata.klass)
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
        relation = belongs_to(name, *options)
        binds << relation
        relation
      end

      def bind_before_save
        before_save :bind_bindings
      end
    end
  end
end
