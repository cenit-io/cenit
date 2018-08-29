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

      def instantiate(attrs = nil, selected_fields = nil, &block)
        super(attrs, selected_fields) do |doc|
          binds.each do |metadata|
            if (id = Setup::Binding.id_for(doc, metadata.klass))
              doc.attributes[metadata.foreign_key] = id
            end
          end
          block.call(doc) if block
        end
      end

      def local_binds
        @binds ||= []
      end

      def binds
        if superclass < Bindings
          superclass.binds
        else
          []
        end + local_binds
      end

      def binding_belongs_to(name, *options)
        relation = belongs_to(name, *options)
        local_binds << relation
        relation
      end

      def where(expression)
        ids = nil
        if expression.is_a?(Hash)
          binds.each do |metadata|
            c_str = expression.delete(metadata.name.to_s)
            c_sym = expression.delete(metadata.name.to_sym)
            if (c = c_sym || c_str).is_a?(metadata.klass)
              ids ||= Set.new
              ids.merge Setup::Binding.where(Setup::Binding.bind_id(metadata.klass) => c.id).collect(&Setup::Binding.binder_id(self).to_sym)
            end
            c_str = expression.delete(metadata.foreign_key.to_s)
            c_sym = expression.delete(metadata.foreign_key.to_sym)
            if (c = c_sym || c_str)
              ids ||= Set.new
              ids.merge Setup::Binding.where(Setup::Binding.bind_id(metadata.klass) => c).collect(&Setup::Binding.binder_id(self).to_sym)
            end
          end
        end
        q = super
        if ids
          q = q.and(:id.in => ids.to_a)
        end
        q
      end

    end
  end
end
