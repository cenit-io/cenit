module Setup
  class BaseDataType

    def merged_schema(options = {})
      sch = merge_schema(JSON.parse(schema), options)
      if (base_sch = sch.delete('extends')).present? && (base_sch = find_ref_schema(base_sch)).present?
        sch = base_sch.deep_merge(sch) { |key, val1, val2| array_sum(val1, val2) }
      end
      sch
    end

    def merge_schema(schema, options = {})
      if schema['allOf'].present? || schema['$ref'].present?
        sch = {}
        schema.each do |key, value|
          if key == 'allOf'
            value.each do |combined_sch|
              if (ref = combined_sch['$ref']).present? && (ref = find_ref_schema(ref)).present?
                combined_sch = ref
              end
              sch = sch.deep_merge(combined_sch) { |key, val1, val2| array_sum(val1, val2) }
            end
          elsif key == '$ref' && (options[:keep_ref].blank? || sch[key].present?) && (ref = find_ref_schema(value)).present?
            sch = sch.reverse_merge(ref) { |key, val1, val2| array_sum(val1, val2) }
          else
            sch[key] = value
          end
        end
        schema = sch
      end
      schema.each { |key, val| schema[key] = merge_schema(val, options) if val.is_a?(Hash) } if options[:recursive].present?
      options[:expand_extends] = true if options[:expand_extends].nil?
      if options[:expand_extends].present? && (base_model = schema['extends']).present?
        base_model = find_ref_schema(base_model) if base_model.is_a?(String)
        base_model = merge_schema(base_model)
        if schema['type'] == 'object' && base_model['type'] != 'object'
          schema['properties'] ||= {}
          value_schema = schema['properties']['value'].presence || {}
          value_schema = base_model.deep_merge(value_schema)
          schema['properties']['value'] = value_schema.merge('title' => 'Value', 'xml' => {'attribute' => false})
          base_model = nil
        else
          schema = base_model.deep_merge(schema) { |key, val1, val2| array_sum(val1, val2) }
        end
      end
      schema
    end

    def find_data_type(ref)
      raise Exception.new('not implemented')
    end

    def find_ref_schema(ref)
      (data_type = find_data_type(ref)).present? ? JSON.parse(data_type.schema) : nil
    end

    def array_sum(val1, val2)
      val1.is_a?(Array) && val2.is_a?(Array) ? val1 + val2 : val2
    end

  end
end