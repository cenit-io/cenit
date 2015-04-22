module Edi
  module Formatter

    def to_edi(options={})
      options.reverse_merge!(field_separator: '*',
                             segment_separator: :new_line,
                             seg_sep_suppress: '<<seg. sep.>>')
      output = record_to_edi(data_type = self.orm_model.data_type, options, JSON.parse(data_type.model_schema), self)
      seg_sep = options[:segment_separator] == :new_line ? "\r\n" : options[:segment_separator].to_s
      output.join(seg_sep)
    end

    def to_hash(options={})
      ignore = (options[:ignore] || [])
      ignore = [ignore] unless ignore.is_a?(Enumerable)
      ignore = ignore.select { |p| p.is_a?(Symbol) || p.is_a?(String) }.collect(&:to_sym)
      options[:ignore] = ignore
      hash = record_to_hash(self, options)
      hash = {self.orm_model.data_type.name.downcase => hash} if options[:include_root]
      hash
    end

    def to_json(options={})
      hash = to_hash(options)
      options[:pretty] ? JSON.pretty_generate(hash) : hash.to_json
    end

    def to_xml(options={})
      (xml_doc = Nokogiri::XML::Document.new) << record_to_xml_element(data_type = self.orm_model.data_type, JSON.parse(data_type.model_schema), self, xml_doc, nil, options)
      xml_doc.to_xml
    end

    private

    def record_to_xml_element(data_type, schema, record, xml_doc, enclosed_property_name, options)
      return unless record
      return Nokogiri::XML({enclosed_property_name => record}.to_xml).root.first_element_child if json_object?(record)
      required = schema['required'] || []
      attr = {}
      elements = []
      content = nil
      content_property = nil
      schema['properties'].each do |property_name, property_schema|
        property_schema = data_type.merge_schema(property_schema)
        name = property_schema['edi']['segment'] if property_schema['edi']
        name ||= property_name
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
          else
            property_schema = data_type.merge_schema(property_schema['items'])
            json_objects = []
            property_value && property_value.each do |sub_record|
              if json_object?(sub_record)
                json_objects << sub_record
              else
                elements << record_to_xml_element(data_type, property_schema, sub_record, xml_doc, property_name, options)
              end
            end
            unless json_objects.empty?
              elements << Nokogiri::XML({property_name => json_objects}.to_xml).root.first_element_child
            end
          end
        when 'object'
          elements << record_to_xml_element(data_type, property_schema, record.send(property_name), xml_doc, property_name, options)
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
              elements << Nokogiri::XML({name => value}.to_xml).root.first_element_child
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

    def record_to_hash(record, options = {}, referenced = false)
       return record if json_object?(record)
       data_type = record.orm_model.data_type
       schema = data_type.merged_schema
       json = (referenced = referenced && schema['referenced_by']) ? {'_reference' => true} : {}
       schema['properties'].each do |property_name, property_schema|
         next if property_schema['virtual'] || (referenced && !referenced.include?(property_name)) || options[:ignore].include?(property_name.to_sym)
         property_schema = data_type.merge_schema(property_schema)
         name = property_schema['edi']['segment'] if property_schema['edi']
         name ||= property_name
         case property_schema['type']
         when 'array'
           property_schema = data_type.merge_schema(property_schema['items'])
           referenced_items = property_schema['referenced'] && !property_schema['export_embedded']
           if value = record.send(property_name)
             value = value.collect { |sub_record| record_to_hash(sub_record, options, referenced_items) }
             json[name] = value unless value.empty?
           end
         when 'object'
           json[name] = value if value =
             record_to_hash(record.send(property_name), options, property_schema['referenced'] && !property_schema['export_embedded'])
         else
           if (value = record.send(property_name)).nil?
             value = property_schema['default']
           end
           json[name] = value unless value.nil?
         end
       end
       json
     end
    

    def record_to_edi(data_type, options, schema, record, enclosed_property_name=nil)
      output = []
      return output unless record
      if schema['edi']
        segment = schema['edi']['segment'] || ''
      else
        header = segment = (enclosed_property_name || record.orm_model.data_type.title)
      end
      schema['properties'].each do |property_name, property_schema|
        property_schema = data_type.merge_schema(property_schema)
        case property_schema['type']
        when 'array'
          property_schema = data_type.merge_schema(property_schema['items'])
          record.send(property_name).each do |sub_record|
            output.concat(record_to_edi(data_type, options, property_schema, sub_record))
          end
        when 'object'
          output.concat(record_to_edi(data_type, options, property_schema, record.send(property_name), property_name))
        else
          unless value = record.send(property_name)
            value = property_schema['default'] || ''
          end
          value =
            if (segment_sep = options[:segment_separator]) == :new_line
              value.to_s.gsub("\r\n", options[:seg_sep_suppress]).gsub("\n", options[:seg_sep_suppress]).gsub("\r", options[:seg_sep_suppress])
            else
              value.to_s.gsub(segment_sep, options[:seg_sep_suppress])
            end
          field_sep = options[:field_separator]
          case field_sep
          when :by_fixed_length
            if (max_len = property_schema['maxLength']) && (auto_fill = property_schema['auto_fill'])
              case auto_fill[0]
              when 'R'
                value += auto_fill[1] until value.length == max_len
              when 'L'
                value = auto_fill[1] + value until value.length == max_len
              end
            end
            segment += value
          else
            segment += field_sep.to_s + value
          end
        end
      end
      output.unshift(segment) unless segment == header
      output
    end

    private

    def json_object?(obj)
      [Hash, Array, Integer, Float, String, TrueClass, FalseClass, Boolean, NilClass].detect { |klass| obj.is_a?(klass) }
    end
  end
end
