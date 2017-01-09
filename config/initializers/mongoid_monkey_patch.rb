require 'mongoid/document'
require 'mongoid/scopable'
require 'mongoid/factory'

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
  end

  module Scopable

    private

    def apply_default_scoping
      if default_scoping
        default_scoping.call.selector.each do |field, value|
          attributes[field] = value unless field.start_with?('$') || value.respond_to?(:each_pair)
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

    def from_db(klass, attributes = nil, selected_fields = nil)
      mongoid_from_db(klass, attributes, selected_fields).tenant_version
    end
  end
end