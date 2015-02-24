module Edi
  module Formatter

    def to_edi(options={})
      options.reverse_merge!(field_separator: '*',
                             segment_separator: :new_line,
                             seg_sep_suppress: '<<seg. sep.>>')
      output = record_to_edi(data_type = self.data_type, options, JSON.parse(data_type.schema), self)
      seg_sep = options[:segment_separator] == :new_line ? "\r\n" : options[:segment_separator].to_s
      output.join(seg_sep)
    end

    def to_json(options={})
      hash = record_to_hash(self)
      hash = {self.class.data_type.name.downcase => hash} if options[:include_root]
      if options[:pretty]
        JSON.pretty_generate(hash)
      else
        hash.to_json
      end
    end

    def to_xml(options={})
      (xml_doc = Nokogiri::XML::Document.new) << record_to_xml_element(data_type = self.class.data_type, JSON.parse(data_type.schema), self, xml_doc, nil, options)
      xml_doc.to_xml
    end

    private

    def record_to_xml_element(data_type, schema, record, xml_doc, enclosed_property_name, options)
      return unless record
      required = schema['required'] || []
      attr = {}
      elements = []
      content = nil
      content_property = nil
      schema['properties'].each do |property_name, property_schema|
        property_schema = data_type.merge_schema(property_schema)
        case property_schema['type']
          when 'array'
            relation = record.reflect_on_association(property_name)
            next unless relation && [:has_many, :has_and_belongs_to_many, :embeds_many].include?(relation.macro)
            property_schema = data_type.merge_schema(property_schema['items'])
            record.send(property_name).each do |sub_record|
              elements << record_to_xml_element(data_type, property_schema, sub_record, xml_doc, nil, options)
            end
          when 'object'
            relation = record.reflect_on_association(property_name)
            next unless relation && [:has_one, :embeds_one].include?(relation.macro)
            elements << record_to_xml_element(data_type, property_schema, record.send(property_name), xml_doc, property_name, options)
          else
            unless value = record.send(property_name)
              value = property_schema['default']
            end
            if value
              name = property_schema['edi']['segment'] if property_schema['edi']
              name ||= property_name
              if !property_schema['xml'] || property_schema['xml']['attribute']
                attr[name] = value if !value.blank? || options[:with_blanks] || required.include?(property_name)
              elsif content.nil?
                content = value
                content_property = property_name
              else
                raise Exception.new("More than one content property found: '#{content_property}' and '#{property_name}'")
              end
            end
        end
      end
      name = schema['edi']['segment'] if schema['edi']
      name ||= enclosed_property_name || record.class.data_type.title
      element = xml_doc.create_element(name, attr)
      if elements.empty?
        element << content unless content.nil?
      else
        raise Exception.new("Incompatible content property ('#{content_property}') in presence of complex content") if content_property
        elements.each { |e| element << e if e }
      end
      element
    end

    def record_to_hash(record, referenced=false)
      return unless record
      data_type = record.class.data_type
      schema = data_type.merged_schema
      json = (referenced = referenced && schema['referenced_by']) ? {'$referenced' => true} : {}
      schema['properties'].each do |property_name, property_schema|
        next if referenced && referenced != property_name
        property_schema = data_type.merge_schema(property_schema)
        name = property_schema['edi']['segment'] if property_schema['edi']
        name ||= property_name
        case property_schema['type']
          when 'array'
            relation = record.reflect_on_association(property_name)
            next unless relation && [:has_many, :has_and_belongs_to_many, :embeds_many].include?(relation.macro)
            referenced_items = relation.macro != :embeds_many && !(data_type.merge_schema(property_schema['items'])['export_embedded'])
            value = record.send(property_name).collect { |sub_record| record_to_hash(sub_record, referenced_items) }
            json[name] = value unless value.empty?
          when 'object'
            relation = record.reflect_on_association(property_name)
            next unless relation && [:has_one, :embeds_one, :belongs_to].include?(relation.macro) #|| (relation.macro == :belongs_to) && relation.inverse_of.nil?)
            if value = record_to_hash(record.send(property_name), relation.macro != :embeds_one && !property_schema['export_embedded'])
              json[name] = value
            end
          else
            unless value = record.send(property_name)
              value = property_schema['default']
            end
            json[name] = value if value
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
        header = segment = (enclosed_property_name || record.data_type.title)
      end
      schema['properties'].each do |property_name, property_schema|
        property_schema = data_type.merge_schema(property_schema)
        case property_schema['type']
          when 'array'
            relation = record.reflect_on_association(property_name)
            next unless relation && [:has_many, :has_and_belongs_to_many, :embeds_many].include?(relation.macro)
            property_schema = data_type.merge_schema(property_schema['items'])
            record.send(property_name).each do |sub_record|
              output.concat(record_to_edi(data_type, options, property_schema, sub_record))
            end
          when 'object'
            relation = record.reflect_on_association(property_name)
            next unless relation && [:has_one, :embeds_one].include?(relation.macro)
            output.concat(record_to_edi(data_type, options, property_schema, record.send(property_name), property_name))
          else
            unless value = record.send(property_name)
              value = property_schema['default'] || ''
            end
            if (segment_sep = options[:segment_separator]) == :new_line
              value = value.to_s.gsub("\r\n", options[:seg_sep_suppress]).gsub("\n", options[:seg_sep_suppress]).gsub("\r", options[:seg_sep_suppress])
            else
              value = value.to_s.gsub(segment_sep, options[:seg_sep_suppress])
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
  end
end