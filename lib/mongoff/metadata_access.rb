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

    MONGO_TYPE_MAP = {
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

    def mongo_type_for(field_or_schema)
      if field_or_schema.is_a?(Hash)
        key = field_or_schema['type']
        if (type = MONGO_TYPE_MAP[key]).is_a?(Hash)
          type = type['format'][field_or_schema['format']] || type['default']
        end
        type
      elsif schema = property_schema(field_or_schema)
        mongo_type_for(schema)
      elsif field_or_schema.to_s == '_id'
        BSON::ObjectId
      else
        nil
      end
    end

    def type_symbol_for(schema)
      mongo_type_for(schema).to_s.downcase.to_sym
    end

    def simple_properties_mongo_types
      (hash = simple_properties_schemas).each { |property, schema| hash[property] = mongo_type_for(schema) }
      hash
    end

    def property_type_symbol(property)
      type_symbol_for(property_schema(property))
    end
  end
end