require 'mongoid/document'
require 'mongoid/scopable'
require 'mongoid/factory'
require 'mongoid/association/relatable'
#require 'mongoid/relations/builders/nested_attributes/many'

class NilClass
  def tenant_version
    nil
  end
end

module Mongoid
  module Document
    def tenant_version
      self
    end

    def reflect_on_all_associations(*macros)
      self.class.reflect_on_all_associations(*macros)
    end

    module ClassMethods
      def get_associations
        relations
      end
    end
  end

  module Scopable
    private

    # upgrade ready
    def apply_default_scoping
      if default_scoping
        default_scoping.call.selector.each do |field, value|
          attributes[field] = value unless field.start_with?('$') || value.respond_to?(:each)
        end
      end
    end
  end

  module Factory
    alias_method :mongoid_build, :build

    def build(klass, attributes = nil)
      mongoid_build(klass, attributes).tenant_version
    end

    alias_method :mongoid_from_db, :from_db

    def from_db(klass, attributes = nil, criteria = nil, selected_fields = nil)
      mongoid_from_db(klass, attributes, criteria, selected_fields).tenant_version
    end
  end

  module Association

    module Relatable

      def macro
        @_macro ||= self.class.to_s.split('::').last.underscore.to_sym
      end

      def many?
        macro.to_s =~ /many/
      end

      def embedded?
        macro == :embeds_one || macro == :embeds_many
      end

      # TODO Make a pull request with this
      def resolve_name(mod, name)
        cls = exc = nil
        parts = name.to_s.split('::')
        if parts.first == ''
          parts.shift
          hierarchy = [Object]
        else
          hierarchy = namespace_hierarchy(mod)
        end
        hierarchy.each do |ns|
          begin
            parts.each do |part|
              # Simple const_get sometimes pulls names out of weird scopes,
              # perhaps confusing the receiver (ns in this case) with the
              # local scope. Walk the class hierarchy ourselves one node
              # at a time by specifying false as the second argument.
              ns = ns.const_get(part, false)
            end
            cls = ns
            break
          rescue NameError, LoadError => e
            if exc.nil?
              exc = e
            end
          end
        end
        if cls.nil?
          # Raise the first exception, this is from the most specific namespace
          raise exc
        end
        cls
      end
    end
  end

  # TODO Upgrading: Check process nested attributes monkey patch
  # module Relations
  #   module Builders
  #     module NestedAttributes
  #       class Many
  #
  #         def process_attributes(parent, attrs)
  #           return if reject?(parent, attrs)
  #           doc = not_found = nil
  #           if (id = attrs.extract_id)
  #             first = existing.first
  #             converted = first ? convert_id(first.class, id) : id
  #             begin
  #               doc = existing.find(converted)
  #             rescue Mongoid::Errors::DocumentNotFound => not_found
  #             end
  #           end
  #           if doc
  #             if destroyable?(attrs)
  #               destroy(parent, existing, doc)
  #             else
  #               update_document(doc, attrs)
  #             end
  #           else
  #             raise not_found unless not_found.nil? || metadata.embedded?
  #             existing.push(Factory.build(metadata.klass, attrs)) unless destroyable?(attrs)
  #           end
  #         end
  #       end
  #     end
  #   end
  # end
end