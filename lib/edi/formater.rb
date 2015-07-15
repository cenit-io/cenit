module Edi
  module Formatter

    def to_params(options={})
      to_hash(options).to_params(options)
    end

    def to_edi(options={})
      options.reverse_merge!(field_separator: '*',
                             segment_separator: :new_line,
                             seg_sep_suppress: '<<seg. sep.>>',
                             inline_field_separator: ':')
      output = record_to_edi(data_type = (model = self.orm_model).data_type, options, model.schema, self)
      seg_sep = options[:segment_separator] == :new_line ? "\r\n" : options[:segment_separator].to_s
      output.join(seg_sep)
    end

    def to_hash(options={})
      include_id = options[:include_id].present?
      [:ignore, :only, :embedding, :inspecting].each do |option|
        value = (options[option] || [])
        value = [value] unless value.is_a?(Enumerable)
        value = value.select { |p| p.is_a?(Symbol) || p.is_a?(String) }.collect(&:to_sym)
        options[option] = value
        include_id ||= (value.include?(:id) || value.include?(:_id))
      end
      [:only, :inspecting].each { |option| options.delete(option) if options[option].empty? }
      options[:inspected_records] = Set.new
      options[:stack] = []
      options[:include_id] = include_id
      hash = record_to_hash(self, options)
      options.delete(:stack)
      hash = {self.orm_model.data_type.name.downcase => hash} if options[:include_root]
      hash
    end

    def to_json(options={})
      hash = to_hash(options)
      options[:pretty] ? JSON.pretty_generate(hash) : hash.to_json
    end

    def to_xml_element(options = {})
      unless xml_doc = options[:xml_doc]
        options[:xml_doc] = xml_doc = Nokogiri::XML::Document.new
      end
      record_to_xml_element(data_type = self.orm_model.data_type, JSON.parse(data_type.model_schema), self, xml_doc, nil, options)
    end

    def to_xml(options = {})
      element = to_xml_element(options)
      options[:xml_doc] << element
      options[:xml_doc].to_xml
    end

    alias_method :inspect_json, :to_hash

    private

    def record_to_xml_element(data_type, schema, record, xml_doc, enclosed_property_name, options)
      return unless record
      return Nokogiri::XML({enclosed_property_name => record}.to_xml(dasherize: false)).root.first_element_child if Cenit::Utility.json_object?(record)
      required = schema['required'] || []
      attr = {}
      elements = []
      content = nil
      content_property = nil
      schema['properties'].each do |property_name, property_schema|
        property_schema = data_type.merge_schema(property_schema)
        name = property_schema['edi']['segment'] if property_schema['edi']
        name ||= property_name
        property_model = record.orm_model.property_model(property_name)
        case property_schema['type']
          when 'array'
            property_value = record.send(property_name)
            xml_opts = property_schema['xml'] || {}
            if xml_opts['attribute']
              property_value = property_value && property_value.collect(&:to_s).join(' ')
              attr[name] = property_value if !property_value.blank? || options[:with_blanks] || required.include?(property_name)
            elsif xml_opts['simple_type']
              elements << (e = xml_doc.create_element(name))
              e << property_value && property_value.collect(&:to_s).join(' ')
            elsif property_model && property_model.modelable?
              property_schema = data_type.merge_schema(property_schema['items'] || {})
              json_objects = []
              property_value.each do |sub_record|
                if Cenit::Utility.json_object?(sub_record)
                  json_objects << sub_record
                else
                  elements << record_to_xml_element(data_type, property_schema, sub_record, xml_doc, property_name, options)
                end
              end if property_value
              unless json_objects.empty?
                elements << Nokogiri::XML({property_name => json_objects}.to_xml(dasherize: false)).root.first_element_child
              end
            else
              elements << Nokogiri::XML({name => property_value}.to_xml(dasherize: false)).root.first_element_child
            end
          when 'object'
            if property_model && property_model.modelable?
              elements << record_to_xml_element(data_type, property_schema, record.send(property_name), xml_doc, property_name, options)
            else
              elements << Nokogiri::XML({name => record.send(property_name)}.to_xml(dasherize: false)).root.first_element_child
            end
          else
            value = property_schema['default'] unless value = record.send(property_name)
            if value
              xml_opts = property_schema['xml'] || {}
              if xml_opts['attribute']
                attr[name] = value if !value.blank? || options[:with_blanks] || required.include?(property_name)
              elsif xml_opts['content']
                if content.nil?
                  content = value
                  content_property = property_name
                else
                  raise Exception.new("More than one content property found: '#{content_property}' and '#{property_name}'")
                end
              else
                elements << Nokogiri::XML({name => value}.to_xml(dasherize: false)).root.first_element_child
              end
            end
        end
      end
      name = schema['edi']['segment'] if schema['edi']
      name ||= enclosed_property_name || record.orm_model.data_type.name
      element = xml_doc.create_element(name, attr)
      if elements.empty?
        content =
            case content
              when NilClass
                []
              when Hash
                Nokogiri::XML(content.to_xml).root.element_children
              else
                [content]
            end
        content.each { |e| element << e }
      else
        raise Exception.new("Incompatible content property ('#{content_property}') in presence of complex content") if content_property
        elements.each { |e| element << e if e }
      end
      element
    end

    def record_to_hash(record, options = {}, referenced = false, enclosed_model = nil)
      return record if Cenit::Utility.json_object?(record)
      data_type = record.orm_model.data_type
      schema = record.orm_model.schema
      json = (referenced = referenced && schema['referenced_by']) ? {'_reference' => true} : {}
      return nil if options[:stack].include?(record)
      if !referenced
        return nil if options[:inspected_records].include?(record)
        options[:inspected_records] << record
      end
      options[:stack] << record
      schema['properties']['_id'] ||= {'_id' => {'type' => 'string'}, 'edi' => {'segment' => 'id'}} if options[:include_id]
      schema['properties'].each do |property_name, property_schema|
        property_schema = data_type.merge_schema(property_schema)
        property_model = record.orm_model.property_model(property_name)
        name = property_schema['edi']['segment'] if property_schema['edi']
        name ||= property_name
        can_be_referenced = !(options[:embedding_all] || options[:embedding].include?(name.to_sym))
        if inspecting = options[:inspecting]
          next unless (property_model || inspecting.include?(name.to_sym))
        else
          next if property_schema['virtual'] ||
              ((property_schema['edi'] || {})['discard'] && !(included_anyway = options[:including_discards])) ||
              (can_be_referenced && referenced && !referenced.include?(property_name)) ||
              options[:ignore].include?(name.to_sym) ||
              (options[:only] && !options[:only].include?(name.to_sym) && !included_anyway)
        end
        case property_schema['type']
          when 'array'
            referenced_items = can_be_referenced && property_schema['referenced'] && !property_schema['export_embedded']
            if value = record.send(property_name)
              new_value = []
              value.each do |sub_record|
                next if inspecting && (scope = options[:inspect_scope]) && !scope.include?(sub_record)
                new_value << record_to_hash(sub_record, options, referenced_items, property_model)
              end
              json[name] = new_value if new_value.present? || options[:include_blanks] || options[:include_empty]
            else
              json[name] = nil if options[:include_null]
            end
          when 'object'
            sub_record = record.send(property_name)
            next if inspecting && (scope = options[:inspect_scope]) && !scope.include?(sub_record)
            value = record_to_hash(sub_record, options, can_be_referenced && property_schema['referenced'] && !property_schema['export_embedded'], property_model)
            store(json, name, value, options)
          else
            if (value = record.send(property_name) || property_schema['default']).is_a?(BSON::ObjectId)
              value = value.to_s
            end
            store(json, name, value, options)
        end
      end
      if !options[:inspecting] && !json['_reference'] && enclosed_model && !record.orm_model.eql?(enclosed_model) && !options[:ignore].include?(:_type) && (!options[:only] || options[:only].include?(:_type))
        json['_type'] = data_type.name
      end
      options[:stack].pop
      json
    end

    def store(json, key, value, options)
      if value
        if value.is_a?(Array) || value.is_a?(Hash)
          json[key] = value if value.present? || options[:include_blanks] || options[:include_empty]
        else
          json[key] = value
        end
      else
        json[key] = nil if options[:include_null]
      end
    end

    def record_to_edi(data_type, options, schema, record, enclosed_property_name=nil)
      output = []
      return output unless record
      field_sep = options[:field_separator]
      segment =
          if (edi_options = schema['edi'] || {})['virtual']
            ''
          else
            edi_options['segment'] ||
                if (record_data_type = record.orm_model.data_type) != data_type
                  record_data_type.name
                else
                  enclosed_property_name || data_type.name
                end
          end
      schema['properties'].each do |property_name, property_schema|
        property_schema = data_type.merge_schema(property_schema)
        next if property_schema['edi'] && property_schema['edi']['discard']
        if (property_model = record.orm_model.property_model(property_name)) && property_model.modelable?
          if property_schema['type'] == 'array'
            property_schema = data_type.merge_schema(property_schema['items'])
            record.send(property_name).each do |sub_record|
              output.concat(record_to_edi(data_type, options, property_schema, sub_record, property_name))
            end
          else
            if sub_record = record.send(property_name)
              if property_schema['edi'] && property_schema['edi']['inline']
                value = []
                property_model.properties_schemas.each do |property_name, property_schema|
                  value << edi_value(sub_record, property_name, property_schema, sub_record.orm_model.property_model(property_name), options)
                end
                segment +=
                    if field_sep == :by_fixed_length
                      value.join
                    else
                      while value.last.blank?
                        value.pop
                      end
                      field_sep + value.join(options[:inline_field_separator])
                    end
              else
                output.concat(record_to_edi(data_type, options, property_schema, sub_record, property_name))
              end
            end
          end
        else
          value = edi_value(record, property_name, property_schema, property_model, options)
          segment +=
              if field_sep == :by_fixed_length
                value
              else
                field_sep + value
              end
        end
      end
      while segment.end_with?(field_sep)
        segment = segment.chomp(field_sep)
      end
      output.unshift(segment) unless edi_options['virtual']
      output
    end

    def edi_value(record, property_name, property_schema, property_model, options)
      unless value = record[property_name]
        value = property_schema['default'] || ''
      end
      value = property_model.to_string(value) if property_model
      value =
          if (segment_sep = options[:segment_separator]) == :new_line
            value.to_s.gsub(/(\n|\r|\r\n)+/, options[:seg_sep_suppress])
          else
            value.to_s.gsub(segment_sep, options[:seg_sep_suppress])
          end
      if options[:field_separator] == :by_fixed_length
        if (max_len = property_schema['maxLength']) && (auto_fill = property_schema['auto_fill'])
          case auto_fill[0]
            when 'R'
              value += auto_fill[1] until value.length == max_len
            when 'L'
              value = auto_fill[1] + value until value.length == max_len
          end
        end
      end
      value
    end
  end
end

class Hash

  def to_params(options={})
    unsafe = options[:unsafe]
    sort.map do |k, values|
      if values.is_a?(Array)
        values << nil if values.empty?
        values.sort.collect do |v|
          [escape(k, unsafe), escape(v, unsafe)] * '='
        end
      elsif values.is_a?(Hash)
        normalize_nested_query(values, k, unsafe)
      else
        [escape(k, unsafe), escape(values, unsafe)] * '='
      end
    end * '&'
  end

  private

  def normalize_nested_query(value, prefix, unsafe)
    case value
      when Array
        value.map do |v|
          normalize_nested_query(v, "#{prefix}[]", unsafe)
        end.flatten.sort
      when Hash
        value.map do |k, v|
          normalize_nested_query(v, prefix ? "#{prefix}[#{k}]" : k, unsafe)
        end.flatten.sort
      else
        [escape(prefix, unsafe), escape(value, unsafe)] * '='
    end
  end

  def escape(value, unsafe)
    URI::escape(value.to_s, unsafe)
  rescue ArgumentError
    URI::escape(value.to_s.force_encoding(Encoding::UTF_8), unsafe)
  end
end
