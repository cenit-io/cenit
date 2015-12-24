module Setup
  module SchemaHandler

    def schema
      fail NotImplementedError
    end

    def object_schema?(schema)
      schema['type'] == 'object' && schema['properties']
    end

    def merged_schema(options = {})
      sch = merge_schema(schema, options)
      unless (base_sch = sch.delete('extends')).nil? || (base_sch = find_ref_schema(base_sch)).nil?
        sch = base_sch.deep_merge(sch) { |_, val1, val2| Cenit::Utility.array_hash_merge(val1, val2) }
      end
      check_id_property(sch)
      sch
    end

    def check_id_property(json_schema)
      return json_schema unless json_schema['type'] == 'object' && !(properties = json_schema['properties']).nil?
      _id, id = properties.delete('_id'), properties.delete('id')
      fail Exception, 'Defining both id and _id' if _id && id
      if _id ||= id
        naked_id = _id.reject { |k, _| %w(unique title description edi format).include?(k) }
        type = naked_id.delete('type')
        fail Exception, "Invalid id property type #{id}" unless naked_id.empty? && (type.nil? || !%w(object array).include?(type))
        json_schema['properties'] = properties = {'_id' => _id.merge('unique' => true,
                                                                     'title' => 'Id',
                                                                     'description' => 'Required',
                                                                     'edi' => {'segment' => 'id'})}.merge(properties)
        unless (required = json_schema['required']).present?
          required = json_schema['required'] = []
        end
        required.delete('_id')
        required.delete('id')
        required.unshift('_id')
      end
      properties.each { |_, property_schema| check_id_property(property_schema) if property_schema.is_a?(Hash) }
      json_schema
    end

    def merge_schema!(schema, options = {})
      merge_schema(schema, options.merge(silent: false))
    end

    def merge_schema(schema, options = {})
      do_merge_schema(schema, options)
    end

    def find_data_type(ref, library_id = self.library_id)
      if optimizer = Setup::DataTypeOptimizer.optimizer
        optimizer.find_data_type(ref, library_id)
      else
        nil
      end
    end

    def library_id
      nil
    end

    def find_ref_schema(ref, root_schema = schema)
      if ref.start_with?('#')
        get_embedded_schema(ref, root_schema)[1] rescue nil
      else
        if data_type = find_data_type(ref)
          data_type.schema
        else
          nil
        end
      end
    end

    def get_embedded_schema(ref, root_schema, root_name='')
      raise Exception.new("invalid format for embedded reference #{ref}") unless ref =~ /\A#(\/[a-z]+(_|([0-9]|[a-z])+)*)*\Z/
      raise Exception.new("embedding itself (referencing '#')") if ref.eql?('#')
      tokens = ref.split('/')
      tokens.shift
      type = root_name
      while tokens.present?
        token = tokens.shift
        raise Exception.new("use invalid embedded reference path '#{ref}'") unless (root_schema.nil? || root_schema = root_schema[token]) && (%w{properties definitions}.include?(token) && !tokens.empty?)
        token = tokens.shift
        raise Exception.new("use invalid embedded reference path '#{ref}'") unless (root_schema.nil? || root_schema = root_schema[token])
        type = root_name.empty? ? token.camelize : "#{type}::#{token.camelize}"
      end
      raise Exception.new("use invalid embedded reference path '#{ref}'") unless root_schema.is_a?(Hash)
      [type, root_schema]
    end

    def check_embedded_ref(ref, root_schema, root_name='')
      type, _ = get_embedded_schema(ref, root_schema, root_name)
      type
    end

    private

    def do_merge_schema(schema, options = {})
      if schema.is_a?(Array)
        return schema.collect { |sch| do_merge_schema(sch, options) }
      end
      return schema unless schema.is_a?(Hash)
      schema = schema.deep_dup
      options ||= {}
      options[:root_schema] ||= schema
      options[:silent] = true if options[:silent].nil?
      references = Set.new
      merging = true
      merged = false
      while merging
        merging = false
        if (options[:expand_extends].nil? && options[:only_overriders].nil?) || options[:expand_extends]
          while base_model = schema.delete('extends')
            merged = merging = true
            base_model = find_ref_schema(base_model) if base_model.is_a?(String)
            base_model = do_merge_schema(base_model)
            if schema['type'] == 'object' && base_model['type'] != 'object'
              schema['properties'] ||= {}
              value_schema = schema['properties']['value'] || {}
              value_schema = base_model.deep_merge(value_schema)
              schema['properties']['value'] = value_schema.merge('title' => 'Value', 'xml' => {'content' => true})
              schema['xml'] ||= {}
              schema['xml']['content_property'] = 'value'
            else
              unless (xml_opts = schema['xml']).nil? || xml_opts['content_property']
                schema['xml'].delete('content_property') if (xml_opts = base_model['xml']) && xml_opts['content_property']
              end
              schema = base_model.deep_merge(schema) { |_, val1, val2| Cenit::Utility.array_hash_merge(val1, val2) }
            end
          end
        elsif options[:only_overriders]
          while base_model = schema.delete('extends') || options.delete(:extends)
            merged = merging = true
            base_model = find_ref_schema(base_model) if base_model.is_a?(String)
            base_model = do_merge_schema(base_model)
            schema['extends'] = base_model['extends'] if base_model['extends']
            if base_properties = base_model['properties']
              properties = schema['properties'] || {}
              base_properties.reject! { |property_name, _| properties[property_name].nil? }
              schema = {'properties' => base_properties}.deep_merge(schema) do |_, val1, val2|
                Cenit::Utility.array_hash_merge(val1, val2)
              end unless base_properties.blank?
            end
          end
        end
        while refs = schema['$ref']
          merged = merging = true
          refs = [refs] unless refs.is_a?(Array)
          refs.each do |ref|
            if references.include?(ref)
              if options[:silent]
                schema.delete('$ref')
              else
                raise Exception.new("contains a circular reference #{ref}")
              end
            else
              references << ref
            end
          end
          sch = {}
          schema.each do |key, value|
            if key == '$ref' && (!options[:keep_ref] || sch[key])
              value = [value] unless value.is_a?(Array)
              value.each do |ref|
                if ref_sch = find_ref_schema(ref)
                  sch = sch.reverse_merge(ref_sch) { |_, val1, val2| Cenit::Utility.array_hash_merge(val1, val2) }
                else
                  raise Exception.new("contains an unresolved reference #{value}") unless options[:silent]
                end
              end
            else
              case existing_value = sch[key]
              when Hash
                if value.is_a?(Hash)
                  value = existing_value.deep_merge(value) { |_, val1, val2| Cenit::Utility.array_hash_merge(val1, val2) }
                end
              when Array
                value = value + existing_value if value.is_a?(Array)
              end
              sch[key] = value
            end
          end
          schema = sch
        end
      end
      schema.each do |key, val|
        if val.is_a?(Hash)
          schema[key] = do_merge_schema(val, options)
        elsif val.is_a?(Array)
          schema[key] = val.collect { |sub_val| sub_val.is_a?(Hash) ? do_merge_schema(sub_val, options) : sub_val }
        end
      end if options[:recursive] || (options[:until_merge] && !merged)
      schema
    end
  end
end
