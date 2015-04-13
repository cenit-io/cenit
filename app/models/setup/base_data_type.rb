module Setup
  class BaseDataType
    def new_from_edi(data, options = {})
      Edi::Parser.parse_edi(self, data, options)
    end

    def new_from_json(data, options = {})
      Edi::Parser.parse_json(self, data, options)
    end

    def new_from_xml(data, options = {})
      Edi::Parser.parse_xml(self, data, options)
    end

    def model_schema
      fail NotImplementedError
    end

    def merged_schema(options = {})
      sch = merge_schema(JSON.parse(model_schema), options)
      unless (base_sch = sch.delete('extends')).nil? || (base_sch = find_ref_schema(base_sch)).nil?
        sch = base_sch.deep_merge(sch) { |_, val1, val2| array_sum(val1, val2) }
      end
      check_id_property(sch)
      sch
    end

    def check_id_property(json_schema)
      return unless json_schema['type'] == 'object' && !(properties = json_schema['properties']).nil?
      _id, id = properties.delete('_id'), properties.delete('id')
      fail Exception, 'Defining both id and _id' if _id && id
      if _id ||= id
        fail Exception, "Invalid id property type #{id}" unless _id.size == 1 && _id['type'] && !%w(object array).include?(_id['type'])
        json_schema['properties'] = properties = { '_id' => _id.merge('unique' => true,
                                                                      'title' => 'Id',
                                                                      'description' => 'Required',
                                                                      'edi' => { 'segment' => 'id' }) }.merge(properties)
        unless (required = json_schema['required']).present?
          required = json_schema['required'] = []
        end
        required.delete('_id')
        required.delete('id')
        required.unshift('_id')
      end
      properties.each { |_, property_schema| check_id_property(property_schema) if property_schema.is_a?(Hash) }
    end

    def merge_schema(schema, options = {})
      if schema['allOf'] || schema['$ref']
        sch = {}
        schema.each do |key, value|
          if key == 'allOf'
            value.each do |combined_sch|
              if (ref = combined_sch['$ref']) && (ref = find_ref_schema(ref))
                combined_sch = ref
              end
              sch = sch.deep_merge(combined_sch) { |_, val1, val2| array_sum(val1, val2) }
            end
          elsif key == '$ref' && (!options[:keep_ref] || sch[key]) && !(ref = find_ref_schema(value)).nil?
            sch = sch.reverse_merge(ref) { |_, val1, val2| array_sum(val1, val2) }
          else
            sch[key] = value
          end
        end
        schema = sch
      end
      schema.each { |key, val| schema[key] = merge_schema(val, options) if val.is_a?(Hash) } if options[:recursive]
      options[:expand_extends] = true if options[:expand_extends].nil?
      if options[:expand_extends] && (base_model = schema['extends']).present?
        base_model = find_ref_schema(base_model) if base_model.is_a?(String)
        base_model = merge_schema(base_model)
        if schema['type'] == 'object' && base_model['type'] != 'object'
          schema['properties'] ||= {}
          value_schema = schema['properties']['value'] || {}
          value_schema = base_model.deep_merge(value_schema)
          schema['properties']['value'] = value_schema.merge('title' => 'Value', 'xml' => { 'attribute' => false })
        else
          schema = base_model.deep_merge(schema) { |_, val1, val2| array_sum(val1, val2) }
        end
      end
      schema
    end

    def find_data_type(ref)
      fail Exception, "#{ref} not implemented"
    end

    def find_ref_schema(ref)
      (data_type = find_data_type(ref)) ? JSON.parse(data_type.model_schema) : nil
    end

    def array_sum(val1, val2)
      val1.is_a?(Array) && val2.is_a?(Array) ? val1 + val2 : val2
    end
  end
end
