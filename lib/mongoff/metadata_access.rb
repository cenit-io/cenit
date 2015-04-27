module Mongoff
  module MetadataAccess

    def properties_schemas
      ((schema = self.schema)['type'] == 'object' && schema['properties']) || {}
    end

    def simple_properties_schemas
      properties_schemas.select { |_, schema| %w(integer number boolean string).include?(schema['type']) }
    end

    def property_schema(property)
      properties_schemas[property.to_s]
    end

    RUBY_TYPE_MAP = {
      integer: Integer,
      number: Float,
      boolean: Boolean,
      string: {
        default: String,
        format: {
          date: Date,
          :'date-time' => DateTime,
          time: Time
        }
      },
      object: Hash,
      array: Array,
      nil: Hash
    }.deep_stringify_keys

    def ruby_type_for(schema)
      if (type = RUBY_TYPE_MAP[schema['type']]).is_a?(Hash)
        type = type['format'][schema['format']] || type['default']
      end
      type
    end

    def type_symbol_for(schema)
      ruby_type_for(schema).to_s.downcase.to_sym
    end

    def property_ruby_type(property)
      ruby_type_for(property_schema(property))
    end

    def simple_properties_ruby_types
      (hash = simple_properties_schemas).each { |property, schema| hash[property] = ruby_type_for(schema) }
      hash
    end

    def property_type_symbol(property)
      type_symbol_for(property_schema(property))
    end
  end
end