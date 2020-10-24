module Setup
  class DataTypeExpansion < Setup::Task

    build_in_data_type

    deny :copy, :new, :edit, :translator_update, :import, :convert, :delete_all

    def run(message)
      message = message.with_indifferent_access
      data_types =
        case source = message[:source]
        when nil # All data types
          Setup::JsonDataType.all
        when Array # bulk schema ids
          Setup::JsonDataType.any_in(id: source)
        else
          [source]
        end
      data_types.each do |data_type|
        next if data_type.nil?
        segments = {}
        refs = Set.new
        schema = data_type.merged_schema(ref_collector: refs)
        if schema['type'] == 'object' && (properties = schema['properties'])
          properties = data_type.merge_schema(properties, ref_collector: refs, until_merge: true)
          properties.each do |property_name, property_schema|
            property_segment = nil
            property_schema = data_type.merge_schema(property_schema, ref_collector: refs, until_merge: true)
            if property_schema['type'] == 'array' && (items = property_schema['items'])
              property_schema['items'] = items = data_type.merge_schema(items, ref_collector: refs, until_merge: true)
              if items.is_a?(Hash) && (edi_opts = items['edi']) && edi_opts.key?('segment')
                property_segment = edi_opts['segment']
              end
            end
            properties[property_name] = property_schema
            if (edi_opts = property_schema['edi']) && edi_opts.key?('segment')
              property_segment = edi_opts['segment']
            end
            segments[property_segment] = property_name if property_segment
          end
          schema['properties'] = properties
        end
        # TODO: inject refs dependencies
        (schema['edi'] ||= {})['segments'] = segments if message[:segment_shortcuts]
        if data_type.schema != schema
          data_type.schema = schema
          data_type.save
        end
      end
    end

  end
end
