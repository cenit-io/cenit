module Edi
  class Parser

    class << self

      def parse_edi(data_type, content, options={}, record=nil)
        start = options[:start] || 0
        content = content.gsub("\r", '')
        segment_sep = "\n" if (segment_sep = options[:segment_separator]) == :new_line
        raise Exception.new("Record model #{record.orm_model} does not match data type model#{data_type.orm_model}") unless record.nil? || record.orm_model == data_type.records_model
        json, start, record = do_parse_edi(data_type, model = data_type.records_model, content, model.schema, start, options[:field_separator], segment_sep, report={segments: []}, new_record: record)
        raise Exception.new("Unexpected input at position #{start}: #{content[start, content.length - start <= 10 ? content.length - 1 : 10]}") if start < content.length
        report[:json] = json
        report[:scan_size] = start
        report[:record] = record
        record
      end

      def parse_json(data_type, content, options={}, record=nil, model=nil)
        content = JSON.parse(content) unless content.is_a?(Hash)
        ignore = (options[:ignore] || [])
        ignore = [ignore] unless ignore.is_a?(Enumerable)
        ignore = ignore.select { |p| p.is_a?(Symbol) || p.is_a?(String) }.collect(&:to_sym)
        options[:ignore] = ignore
        unless (primary_field_option = options[:primary_field]).nil? || primary_field_option.is_a?(Symbol)
          options[:primary_field] = primary_field_option.to_s.to_sym
        end
        do_parse_json(data_type, data_type.records_model, content, options, (record && record.orm_model.schema) || (model && model.schema) || data_type.merged_schema, nil, record)
      end

      def parse_xml(data_type, content, options={}, record=nil)
        do_parse_xml(data_type, data_type.records_model, content.is_a?(Nokogiri::XML::Element) ? content : Nokogiri::XML(content).root, options, data_type.merged_schema, nil, record)
      end

      private

      def do_parse_xml(data_type, model, element, options, json_schema, record=nil, new_record=nil, enclosed_property=nil)
        json_schema = data_type.merge_schema(json_schema)
        name = json_schema['edi']['segment'] if json_schema['edi']
        name ||= enclosed_property || model.data_type.name
        return unless name == element.name
        record ||= new_record || model.new
        attributes = {}
        attribute_schemas = {}
        sub_element_schemas = {}
        content_property = nil
        json_schema['properties'].each do |property_name, property_schema|
          property_schema = data_type.merge_schema(property_schema)
          name = property_schema['edi'] ? property_schema['edi']['segment'] : property_name
          xml_opts = property_schema['xml'] || {}
          if xml_opts['attribute']
            attributes[name] = property_name
            attribute_schemas[name] = property_schema
          elsif xml_opts['content']
            raise Exception.new("More than one content property found: '#{content_property}' and '#{property_name}'") if content_property
            content_property = property_name
          else
            property_schema[:property_name] = property_name
            sub_element_schemas[name] = property_schema
          end
        end if json_schema['properties']
        element.attribute_nodes.each do |attr|
          if property = attributes[attr.name]
            value =
                if (attr_schema = attribute_schemas[attr.name])['type'] == 'array'
                  attr.value.split(' ')
                else
                  attr.value
                end
            record.send("#{property}=", value)
          end
        end
        if sub_element_schemas.empty?
          if content_property
            content =
                if element.children.empty?
                  element.content
                else
                  Hash.from_xml(element.to_xml).values.first
                end
            record.send("#{content_property}=", content)
          end
        else
          element.element_children.each do |sub_element|
            if property_schema = sub_element_schemas[sub_element.name]
              property_name = property_schema[:property_name]
              case property_schema['type']
                when 'array'
                  property_schema = data_type.merge_schema(property_schema['items'] || {})
                  if (property_model = model.property_model(property_name)) && property_model.modelable?
                    while sub_element && sub_record = do_parse_xml(data_type, property_model, sub_element, options, property_schema, nil, nil, property_name)
                      record.send(property_name) << sub_record
                      sub_element = sub_element.next_element
                    end
                  else
                    record.send("#{property_name}=", Hash.from_xml(sub_element.to_xml).values.first)
                  end
                when 'object'
                  if (property_model = model.property_model(property_name)) && property_model.modelable?
                    if sub_record = do_parse_xml(data_type, property_model, sub_element, options, property_schema, nil, nil, property_name)
                      record.send("#{property_name}=", sub_record)
                    end
                  else
                    record.send("#{property_name}=", Hash.from_xml(sub_element.to_xml).values.first)
                  end
                else
                  record.send("#{property_name}=", Hash.from_xml(sub_element.to_xml).values.first)
              end
            end
          end
        end
        record.try(:run_after_initialized)
        record
      end

      def do_parse_json(data_type, model, json, options, json_schema, record=nil, new_record=nil)
        updating = false
        primary_field = options.delete(:primary_field) || :id
        unless record ||= new_record
          if model && model.modelable?
            if record = (!options[:ignore].include?(primary_field) && (field_value = json[primary_field.to_s]) && model.where(primary_field => field_value).first)
              updating = true
            else
              (record = model.new).instance_variable_set(:@dynamically_created, true)
            end
          else
            return json
          end
        end
        resetting = json['_reset'] || []
        resetting = [resetting] unless resetting.is_a?(Enumerable)
        json_schema = data_type.merge_schema(json_schema)
        json_schema['properties'].each do |property_name, property_schema|
          next if options[:ignore].include?(property_name.to_sym)
          property_schema = data_type.merge_schema(property_schema)
          name = property_schema['edi']['segment'] if property_schema['edi']
          name ||= property_name
          property_model = model.property_model(property_name)
          case property_schema['type']
            when 'array'
              next unless updating | (association = record.send(property_name)).blank?
              items_schema = data_type.merge_schema(property_schema['items'] || {})
              unless !resetting.include?(property_name) && association && property_schema['referenced']
                record.send("#{property_name}=", [])
                association = record.send(property_name)
              end
              if property_value = json[name]
                property_value = [property_value] unless property_value.is_a?(Array)
                property_value.each do |sub_value|
                  if property_model && property_model.persistable? && sub_value['_reference']
                    sub_value = Cenit::Utility.deep_remove(sub_value, '_reference')
                    record.instance_variable_set(:@_references, references = {}) unless references = record.instance_variable_get(:@_references)
                    (references[property_name] ||= []) << {model: property_model, criteria: sub_value}
                    if sub_value = Cenit::Utility.find_record(association, sub_value)
                      association.delete(sub_value)
                    end
                  else
                    if !association.include?(sub_value = do_parse_json(data_type, property_model, sub_value, options, items_schema))
                      association << sub_value
                    end
                  end
                end
              end
            when 'object'
              next if !updating && record.send(property_name)
              if property_value = json[name]
                if property_value['_reference']
                  record.send("#{property_name}=", nil)
                  property_value = Cenit::Utility.deep_remove(property_value, '_reference')
                  record.instance_variable_set(:@_references, references = {}) unless references = record.instance_variable_get(:@_references)
                  references[property_name] = {model: property_model, criteria: property_value}
                else
                  record.send("#{property_name}=", do_parse_json(data_type, property_model, property_value, options, property_schema))
                end
              else
                record.send("#{property_name}=", nil)
              end
            else
              next if (updating && (property_name == '_id' || name == primary_field.to_s))
              if property_value = json[name]
                record.send("#{property_name}=", property_value)
              end
          end
        end

        if (sub_model = json['_type']) &&
            sub_model.is_a?(String) &&
            (sub_model = sub_model.start_with?('self[') ? (json.send(:eval, sub_model) rescue nil) : sub_model) &&
            (data_type = data_type.find_data_type(sub_model)) &&
            (sub_model = data_type.records_model) &&
            !sub_model.eql?(model)
          sub_record = (updating ? record : sub_model.new)
          json_schema['properties'].keys.each do |property_name|
            if value = record.send(property_name)
              sub_record.send("#{property_name}=", value)
              record.send("#{property_name}=", nil)
            end
          end
          record = do_parse_json(data_type, sub_model, json, options, data_type.merged_schema, sub_record)
        end
        record.try(:run_after_initialized)
        record
      end

      def do_parse_edi(data_type, model, content, json_schema, start, field_sep, segment_sep, report, options = {})
        record = options[:record] || options[:new_record] || model.new
        json = options[:json]
        fields = options[:fields]
        segment = options[:segment]
        segment_sep ||= report[:segment_separator]
        json_schema = data_type.merge_schema(json_schema)
        seg_id = (edi_options = json_schema['edi'] || {})['segment'] ||
            if (record_data_type = record.orm_model.data_type) != data_type
              record_data_type.name
            else
              options[:enclosed_property] || data_type.name
            end
        if !edi_options['virtual']
          return [nil, start, nil] unless start < content.length && content[start, seg_id.length] == seg_id
          if (fields_count = model.properties_schemas.count { |property, schema| !model.property_model?(property) && (!schema['edi'] || !schema['edi']['discard']) }) == 0
            segment_sep ||= content[start + seg_id.length]
          else
            field_sep ||= content[start + seg_id.length]
          end unless segment_sep && field_sep
          unless segment_sep
            if field_sep == :by_fixed_length
              cursor = start + seg_id.length
              json_schema['properties'].each do |property_name, property_schema|
                if !%w{object array}.include?(property_schema['type']) && property_schema['$ref'].nil?
                  if (length = property_schema['length']) || ((length = property_schema['maxLength']) && (property_schema['auto_fill'] || length == property_schema['minLength']))
                    cursor += length
                  else
                    raise Exception.new("property #{property_name} has no fixed length or auto fill option is missing while parsing with fixed length option")
                  end
                end
              end
              if cursor < content.length
                puts "Segment separator inferred: #{segment_sep = content[cursor]}"
              else
                puts 'End of content reached no segment separator needs to be inferred'
              end
            else
              if next_seg_property = model.properties_schemas.keys.detect { |property| model.property_model?(property) }
                next_seg_schema = model.property_model(next_seg_property).schema
                next_seg_schema = data_type.merge_schema(next_seg_schema)
                raise Exception.new('Can not infers segment separator without EDI segment metadata in next sub-segment schema') unless next_seg_schema['edi'] && next_seg_id = next_seg_schema['edi']['segment']
                puts "Inferring segment separator with field separator #{field_sep}..."
                cursor = start + seg_id.length + 1
                if fields_count > 0
                  while fields_count > 0
                    cursor = content.index(field_sep, cursor) + 1
                    fields_count -= 1
                  end
                  raise Exception.new('Error inferring segment separator') unless next_seg_id && (content[cursor - next_seg_id.length - 1, next_seg_id.length] == next_seg_id)
                  puts "Segment separator inferred: #{segment_sep = content[cursor - next_seg_id.length - 2]}"
                else
                  segment_sep = cursor < content.length ? content[cursor] : nil
                end
              end
            end
            report[:segment_separator] = segment_sep
          end
          if field_sep == :by_fixed_length
            fields = []
            start += seg_id.length
            top = content.index(segment_sep, start) || content.length
            json_schema['properties'].each do |property_name, property_schema|
              next if start == top
              if !%w{object array}.include?(property_schema['type']) && property_schema['$ref'].nil?
                if (length = property_schema['length']) || ((length = property_schema['maxLength']) && (property_schema['auto_fill'] || length == property_schema['minLength']))
                  length = top - start if start + length >= top
                  fields << content[start, length]
                  start += length
                else
                  raise Exception.new("property #{property_name} has no fixed length or auto fill option is missing while parsing with fixed length option")
                end
              end
            end
          else
            fields = (segment = content[start..(start = (segment_sep && (content.index(segment_sep, start)) || content.length)) - 1]).split(field_sep)
            fields.shift
          end
          if segment_sep && (start == content.length - 1 || content[start, segment_sep.length] != segment_sep)
            puts content.length
            puts "Warning!!!"
            start = content.index(segment_sep, start) || start
          end
          start += segment_sep ? segment_sep.length : 0
        else
          fields = []
        end unless options[:record]
        json ||= {}
        required = json_schema['required'] || []
        json_schema['properties'].each do |property_name, property_schema|
          next if json[property_name]
          property_schema = data_type.merge_schema(property_schema)
          next if property_schema['edi'] && property_schema['edi']['discard']
          if (property_model = model.property_model(property_name)) && property_model.modelable?
            if  property_schema['type'] == 'array'
              property_schema = data_type.merge_schema(property_schema['items'])
              property_json = []
              record[property_name] = [] if record[property_name].nil?
              association = record[property_name]
              while (sub_segment = do_parse_edi(data_type, property_model, content, property_schema, start, field_sep, segment_sep, report, enclosed_property: property_name))[0]
                property_json << sub_segment[0]
                association << sub_segment[2]
                start = sub_segment[1]
              end
              json[property_name] = property_json unless property_json.empty?
            else
              if field = fields.shift #composite field
                property_json = {}
                property_record = property_model.new
                sub_elements = field.split(':')
                property_schema['properties'].each do |key, _|
                  if (sub_element = sub_elements.shift) && !sub_element.blank?
                    property_json[key] = sub_element
                    property_record.send("#{key}=", property_model.mongo_value(sub_element, key))
                  end
                end
                property_json.empty? ? (property_json = nil) : record.send("#{property_name}=", property_record)
              else
                property_json, start, property_record = do_parse_edi(data_type, property_model, content, property_schema, start, field_sep, segment_sep, report, enclosed_property: property_name)
                record.send("#{property_name}=", property_record) if property_record
              end
              json[property_name] = property_json if property_json
            end
          else
            if (field = fields.shift) && field.length != 0
              json[property_name] = field
              record.send("#{property_name}=", model.mongo_value(field, property_name))
            end
          end
          return [nil, start, nil] if !json[property_name] && json.empty? && required.include?(property_name)
        end

        if (sub_model = json['_type']) &&
            sub_model.is_a?(String) &&
            (sub_model = sub_model.start_with?('self[') ? (json.send(:eval, sub_model) rescue nil) : sub_model) &&
            (data_type = data_type.find_data_type(sub_model)) &&
            (sub_model = data_type.records_model) &&
            !sub_model.eql?(model)
          sub_record = sub_model.new
          json_schema['properties'].each do |property_name, property_schema|
            if value = record.send(property_name)
              sub_record.send("#{property_name}=", value)
              record.send("#{property_name}=", nil)
            end
          end
          json, start, record = do_parse_edi(data_type, sub_model, content, data_type.merged_schema, start, field_sep, segment_sep, report, record: sub_record, json: json, fields: fields, segment: segment)
        end

        return [nil, start, nil] if json.empty?

        report[:segments] << [segment, record]

        record.try(:run_after_initialized)
        return [json, start, record]
      end
    end
  end
end