module Edi
  module Formatter

    def to_edi(options = {})
      options.reverse_merge!(
        field_separator: '*',
        segment_separator: :new_line,
        seg_sep_suppress: '<<seg. sep.>>')
      output = record_to_edi(data_type = self.orm_model.data_type, options, JSON.parse(data_type.schema), self)
      seg_sep = options[:segment_separator] == :new_line ? "\r\n" : options[:segment_separator].to_s
      output.join(seg_sep)
    end

    def to_json(options = {})
      hash = record_to_json(self)
      hash = {self.orm_model.data_type.name.downcase => hash} if options[:include_root].present?
      options[:pretty] ? JSON.pretty_generate(hash) : hash.to_json
    end

    def to_xml(options = {})
      (xml_doc = Nokogiri::XML::Document.new) << record_to_xml_element(data_type = self.orm_model.data_type, JSON.parse(data_type.schema), self, xml_doc, nil, options)
      xml_doc.to_xml
    end

    private

    def record_to_xml_element(data_type, schema, record, xml_doc, enclosed_property_name, options)
      return unless record.present?
      required = schema['required'] || []
      attr = {}
      elements = []
      content = nil
      content_property = nil
      schema['properties'].each do |property_name, property_schema|
        property_schema = data_type.merge_schema(property_schema)
        case property_schema['type']
        when 'array'
          property_schema = data_type.merge_schema(property_schema['items'])
          record.send(property_name).each { |sub_record| elements << record_to_xml_element(data_type, property_schema, sub_record, xml_doc, nil, options) }
        when 'object'
          elements << record_to_xml_element(data_type, property_schema, record.send(property_name), xml_doc, property_name, options)
        else
          unless (value = record.send(property_name)).present?
            value = property_schema['default']
          end  
          if value.present?
            name = property_schema['edi']['segment'] if property_schema['edi'].present?
            name ||= property_name
            if property_schema['xml'].blank? || property_schema['xml']['attribute'].present?
              attr[name] = value if value.present? || options[:with_blanks].present? || required.include?(property_name)
            elsif content.nil?
              content = value
              content_property = property_name
            else
              raise Exception.new("More than one content property found: '#{content_property}' and '#{property_name}'")
            end
          end
        end
      end
      name = schema['edi']['segment'] if schema['edi'].present?
      name ||= enclosed_property_name.presence || record.orm_model.data_type.title
      element = xml_doc.create_element(name, attr)
      if elements.empty?
        element << content if content.present?
      else
        raise Exception.new("Incompatible content property ('#{content_property}') in presence of complex content") if content_property.present?
        elements.each { |e| element << e if e }
      end
      element
    end

    def record_to_json(record, referenced = false)
      return if record.nil?
      data_type = record.orm_model.data_type
      schema = data_type.merged_schema
      json = (referenced = referenced && schema['referenced_by']) ? {'$referenced' => true} : {}
      schema['properties'].each do |property_name, property_schema|
        next if referenced.present? && referenced != property_name
        property_schema = data_type.merge_schema(property_schema)
        name = property_schema['edi']['segment'] if property_schema['edi'].present?
        name ||= property_name
        case property_schema['type']
        when 'array'
          property_schema = data_type.merge_schema(property_schema['items'])
          referenced_items = property_schema['referenced'] && !property_schema['export_embedded']
          if value = record.send(property_name)
            value = value.collect { |sub_record| record_to_json(sub_record, referenced_items) }
            json[name] = value if value.present?
          end
        when 'object'
          if (value = record_to_json(record.send(property_name), property_schema['referenced']).present? && !property_schema['export_embedded'])
            json[name] = value
          end
        else
          if (value = record.send(property_name)).nil?
            value = property_schema['default']
          end
          json[name] = value if value.present?
        end
      end
      json
    end

    def record_to_edi(data_type, options, schema, record, enclosed_property_name = nil)
      output = []
      return output if record.blank?
      if schema['edi']
        segment = schema['edi']['segment'].presence || ''
      else
        header = segment = (enclosed_property_name.presence || record.orm_model.data_type.title)
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
          unless (value = record.send(property_name)).present?
            value = property_schema['default'].presence || ''
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
            if (max_len = property_schema['maxLength']).present? && (auto_fill = property_schema['auto_fill']).present?
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
  end
end