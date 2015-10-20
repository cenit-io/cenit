module Mongoff
  module MetadataAccess


    def property_for(name)
      @properties_by_mane ||= {}
      unless @properties_by_mane.has_key?(name)
        segment_property = nil
        name_property = nil
        if (edi_opts = schema['edi']) && segments = edi_opts['segments']
          segment_property = segments[name]
          name_property = name if property?(name)
        else
          properties.each do |property|
            next if segment_property
            schema = property_model(property).schema
            if ((edi_opts = schema['edi']) && edi_opts['segment'] == name)
              segment_property = property
            else
              schema = property_schema(property)
              segment_property = property if ((edi_opts = schema['edi']) && edi_opts['segment'] == name)
            end
            name_property = property if property == name
          end
        end
        @properties_by_mane[name] = segment_property || name_property
      end
      @properties_by_mane[name]
    end

    def properties_schemas
      @properties_schemas ||= ((schema = self.schema).is_a?(Hash) && schema['type'] == 'object' && schema['properties']) || {}
    end

    def simple_properties_schemas
      properties_schemas.select { |_, schema| %w(integer number boolean string).include?(schema['type']) }
    end

    def property_schema(property)
      if sch = properties_schemas[property.to_s]
        data_type.merge_schema(sch)
      else
        nil
      end
    end

    def properties
      properties_schemas.keys
    end

    def property?(property)
      properties_schemas.has_key?(property)
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
      nil => NilClass
    }.with_indifferent_access

    def mongo_type_for(field_or_schema)
      if field_or_schema.is_a?(Hash)
        key = field_or_schema['type']
        if (type = MONGO_TYPE_MAP[key]).is_a?(Hash)
          type = type['format'][field_or_schema['format']] || type['default']
        end
        type
      elsif schema = property_schema(field_or_schema)
        if property_model?(field_or_schema) && schema['referenced']
          BSON::ObjectId #TODO when array schema
        else
          mongo_type_for(schema)
        end
      elsif %w(id _id).include?(str = field_or_schema.to_s) || str.end_with?('_id')
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