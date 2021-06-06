module Setup
  module SchemaHandler
    def schema
      fail NotImplementedError
    end

    def object_schema?(schema)
      schema['type'] == 'object' && schema['properties']
    end

    def merged_schema(options = {})
      if (sch = merge_schema(schema, options))
        unless (base_sch = sch.delete('extends')).nil? || (base_sch = find_ref_schema(base_sch)).nil?
          sch = base_sch.deep_merge(sch) { |_, val1, val2| Cenit::Utility.array_hash_merge(val1, val2) }
        end
        check_properties(sch)
      end
      sch
    end

    def check_properties(json_schema, options = {})
      object_schema =
        case json_schema['type']
        when 'object'
          json_schema
        when 'array'
          json_schema['items']
        else
          nil
        end
      if object_schema && object_schema.is_a?(Hash) && object_schema['type'] == 'object' && (properties = object_schema['properties'])

        # Check #id property
        _id = properties['_id']
        id = properties['id']
        fail Exception, 'defines both id and _id' if _id && id
        edi_discard_id = false
        unless _id ||= id
          edi_discard_id = true
          _id = {}
        end
        naked_id = _id.reject { |k, _| %w(group xml unique title description edi format example enum readOnly default visible).include?(k) }
        type = naked_id.delete('type')
        auto_present = naked_id.key?('auto')
        auto = naked_id.delete('auto')
        fail Exception, "ID property type #{type} is not valid" unless naked_id.empty? && (type.nil? || %w(object array).exclude?(type))
        if auto
          fail Exception, "ID property auto mark should be true" unless auto.is_a?(TrueClass)
          fail Exception, "ID property of type #{type} can not be auto" unless type.nil? || type == 'string'
        else
          fail Exception, "ID property auto mark should not be present or it should be true" if auto_present
        end
        unless options[:skip_id_refactoring]
          properties.delete('id')
          properties.delete('_id')
          object_schema['properties'] = properties = { '_id' => _id.merge('unique' => true,
                                                                          'title' => 'Id',
                                                                          'description' => 'Required',
                                                                          'edi' => { 'segment' => 'id' }) }.merge(properties)
          properties['_id']['edi']['discard'] = true if edi_discard_id
          if auto && type
            properties['_id']['auto'] = true
          else
            properties['_id'].delete('auto')
          end
          unless (required = object_schema['required']).present?
            required = object_schema['required'] = []
          end
          required.delete('_id')
          required.delete('id')
          required.unshift('_id')
        end

        # Check property names
        new_names = {}
        new_properties = {}
        properties.keys.each do |property|
          property_schema = properties.delete(property)
          new_property = property
          if property == 'object' || !(property =~ /\A[A-Za-z_]\w*\Z/)
            c = 1
            new_property = prefix = (property == 'object') ? 'obj' : property.to_s.to_method_name
            while new_properties.key?(new_property) || properties.key?(new_property)
              new_property = "#{prefix}_#{c += 1}"
            end
            property_schema['edi'] = { 'segment' => property }
            new_names[property] = new_property
          end
          new_properties[new_property] = property_schema
        end
        new_properties.each { |property, schema| properties[property] = schema }
        %w(required protected).each do |modifier_key|
          next unless (modifier = object_schema[modifier_key])
          new_names.each do |old_name, new_name|
            modifier << new_name if modifier.delete(old_name)
          end
        end

        # Check recursively
        properties.each { |_, property_schema| check_properties(property_schema, options) if property_schema.is_a?(Hash) }
      end
      json_schema
    end

    def merge_schema!(schema, options = {})
      merge_schema(schema, options.merge(silent: false))
    end

    def merge_schema(schema, options = {})
      do_merge_schema(schema, options)
    end

    def find_data_type(ref, ns = namespace)
      Setup::Optimizer.find_data_type(ref, ns)
    end

    def find_ref_schema(ref, root_schema = schema)
      fragment = ''
      data_type = self
      sch =
        if ref.is_a?(String) && ref.start_with?('#')
          fragment = "#{ref}"
          get_embedded_schema(ref, root_schema)[1] rescue nil
        else
          (data_type = find_data_type(ref)) &&
            data_type.schema
        end
      sch && sch.merge('id' => "#{Cenit.host}/data_type/#{data_type.id}#{fragment}")
    end

    def get_embedded_schema(ref, root_schema, root_name = '')
      fail "invalid format for embedded reference #{ref}" unless ref =~ %r{\A#(\/[a-z]+(_|([0-9]|[a-z])+)*)*\Z}
      fail "embedding itself (referencing '#')" if ref.eql?('#')
      tokens = ref.split('/')
      tokens.shift
      type = root_name
      while tokens.present?
        token = tokens.shift
        fail "use invalid embedded reference path '#{ref}'" unless (root_schema.nil? || (root_schema = root_schema[token])) && (%w(properties definitions).include?(token) && !tokens.empty?)
        token = tokens.shift
        fail "use invalid embedded reference path '#{ref}'" unless root_schema.nil? || (root_schema = root_schema[token])
        type = root_name.empty? ? token.camelize : "#{type}::#{token.camelize}"
      end
      fail "use invalid embedded reference path '#{ref}'" unless root_schema.is_a?(Hash)
      [type, root_schema]
    end

    def check_embedded_ref(ref, root_schema, root_name = '')
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
          while (base_model = schema.delete('extends'))
            merged = merging = true
            base_model = find_ref_schema(ref = base_model) if base_model.is_a?(String)
            if base_model
              base_model = do_merge_schema(base_model)
              if schema['type'] == 'object' && base_model['type'] != 'object'
                schema['properties'] ||= {}
                value_schema = schema['properties']['value'] || {}
                value_schema = base_model.deep_merge(value_schema)
                schema['properties']['value'] = value_schema.merge('title' => 'Value', 'xml' => { 'content' => true })
                schema['xml'] ||= {}
                schema['xml']['content_property'] = 'value'
              else
                unless (xml_opts = schema['xml']).nil? || xml_opts['content_property']
                  schema['xml'].delete('content_property') if (xml_opts = base_model['xml']) && xml_opts['content_property']
                end
                schema = base_model.deep_merge(schema) { |_, ref_value, sch_value| Cenit::Utility.array_hash_merge(ref_value, sch_value) }
              end
            else
              fail "contains an unresolved reference #{ref}" unless options[:silent]
            end
          end
        elsif options[:only_overriders]
          while (base_model = schema.delete('extends') || options.delete(:extends))
            merged = merging = true
            base_model = find_ref_schema(base_model) if base_model.is_a?(String)
            base_model = do_merge_schema(base_model)
            schema['extends'] = base_model['extends'] if base_model['extends']
            next unless (base_properties = base_model['properties'])
            properties = schema['properties'] || {}
            base_properties.reject! { |property_name, _| properties[property_name].nil? }
            schema = { 'properties' => base_properties }.deep_merge(schema) do |_, ref_value, sch_value|
              Cenit::Utility.array_hash_merge(ref_value, sch_value)
            end unless base_properties.blank?
          end
        end
        while (refs = schema['$ref'])
          merged = merging = true
          refs = [refs] unless refs.is_a?(Array)
          refs.each do |ref|
            if references.include?(ref)
              if options[:silent]
                schema.delete('$ref')
              else
                fail "contains a circular reference #{ref}"
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
                if (ref_sch = find_ref_schema(ref))
                  sch = ref_sch.merge(sch) { |_, ref_value, sch_value| Cenit::Utility.array_hash_merge(ref_value, sch_value) }
                else
                  fail "contains an unresolved reference #{value}" unless options[:silent]
                end
              end
            else
              case existing_value = sch[key]
              when Hash
                value = existing_value.deep_merge(value) { |_, sch_value, ref_value| Cenit::Utility.array_hash_merge(sch_value, ref_value) } if value.is_a?(Hash)
              when Array
                value += existing_value if value.is_a?(Array)
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
