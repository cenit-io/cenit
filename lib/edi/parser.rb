module Edi
  class Parser

    class << self

      def parse_edi(data_type, content, options={}, record=nil)
        start = options[:start] || 0
        if (segment_sep = options[:segment_separator]) == :new_line
          content = content.gsub("\r", '')
          segment_sep = "\n"
        end
        raise Exception.new("Record model #{record.orm_model} does not match data type model#{data_type.orm_model}") unless record.nil? || record.orm_model == data_type.records_model
        json, start, record = do_parse_edi(data_type, data_type.model, content, data_type.merged_schema, start, options[:field_separator], segment_sep, report={segments: []}, nil, nil, nil, nil, record)
        raise Exception.new("Unexpected input at position #{start}: #{content[start, content.length - start <= 10 ? content.length - 1 : 10]}") if start < content.length
        report[:json] = json
        report[:scan_size] = start
        report[:record] = record
        record
      end

      def parse_json(data_type, content, options={}, record=nil)
        content = JSON.parse(content) unless content.is_a?(Hash)
        do_parse_json(data_type, data_type.records_model, content, options, data_type.merged_schema, nil, record)
      end

      def parse_xml(data_type, content, options={}, record=nil)
        do_parse_xml(data_type, data_type.records_model, Nokogiri::XML(content).root, options, data_type.merged_schema, nil, record)
      end

      private

      def do_parse_xml(data_type, model, element, options, json_schema, record=nil, new_record=nil, enclosed_property=nil)
        json_schema = data_type.merge_schema(json_schema)
        name = json_schema['edi']['segment'] if json_schema['edi']
        name ||= enclosed_property || model.data_type.title
        return unless name == element.name
        record ||= new_record || model.new
        attributes = {}
        sub_element_schemas = {}
        content_property = nil
        json_schema['properties'].each do |property_name, property_schema|
          property_schema = data_type.merge_schema(property_schema)
          name = property_schema['edi'] ? property_schema['edi']['segment'] : property_name
          if %w{object array}.include?(property_schema['type'])
            sub_element_schemas[property_name] = property_schema
          elsif !property_schema['xml'] || property_schema['xml']['attribute']
            attributes[name] = property_name
          else
            raise Exception.new("More than one content property found: '#{content_property}' and '#{property_name}'") if content_property
            content_property = property_name
          end
        end
        element.attribute_nodes.each do |attr|
          #raise Exception.new("Unexpected attribute '#{attr.name}'") unless property = attributes[attr.name]
          if property = attributes[attr.name]
            record.send("#{property}=", attr.value)
          end
        end
        if sub_element_schemas.empty?
          record.send("#{content_property}=", element.content) if content_property
        else
          sub_element = element.first_element_child
          sub_element_schemas.each do |property_name, property_schema|
            next unless sub_element
            case property_schema['type']
            when 'array'
              relation = model.reflect_on_association(property_name)
              next unless [:has_many, :has_and_belongs_to_many, :embeds_many].include?(relation.macro)
              property_schema = data_type.merge_schema(property_schema['items'])
              property_model = relation.klass
              while sub_element && sub_record = do_parse_xml(data_type, property_model, sub_element, options, property_schema)
                record.send(property_name) << sub_record
                sub_element = sub_element.next_element
              end
            when 'object'
              relation = model.reflect_on_association(property_name)
              next unless [:has_one, :embeds_one].include?(relation.macro)
              property_model = relation.klass
              if sub_record = do_parse_xml(data_type, property_model, sub_element, options, property_schema, nil, nil, property_name)
                record.send("#{property_name}=", sub_record)
                sub_element = sub_element.next_element
              end
            else
              raise Exception.new('These should not be read')
            end
          end
        end
        record.try(:run_after_initialized)
        record
      end

      def do_parse_json(data_type, model, json, options, json_schema, record=nil, new_record=nil)
        json_schema = data_type.merge_schema(json_schema)
        record ||= new_record || model.new
        json_schema['properties'].each do |property_name, property_schema|
          property_schema = data_type.merge_schema(property_schema)
          name = property_schema['edi']['segment'] if property_schema['edi']
          name ||= property_name
          property_model = model.for_property(property_name)
          case property_schema['type']
          when 'array'
            next unless (property_value = record.send(property_name)).nil? || property_value.empty?
            record.send("#{property_name}=", []) if property_value.nil?
            if property_value = json[name]
              raise Exception.new("Array value expected for property #{property_name} but #{property_value.class} found: #{property_value}") unless property_value.is_a?(Array)
              property_schema = data_type.merge_schema(property_schema['items'])
              property_value.each do |sub_value|
                if sub_value['$referenced']
                  sub_value = sub_value.reject { |k, _| k == '$referenced' }
                  if (criteria = property_model.where(sub_value)).empty?
                    record.instance_variable_set(:@_references, references = {}) unless references = record.instance_variable_get(:@_references)
                    (references[property_name] ||= []) << {model: property_model, criteria: sub_value}
                  else
                    (record.send(property_name)) << criteria.first
                  end
                else
                  (record.send(property_name)) << do_parse_json(data_type, property_model, sub_value, options, property_schema)
                end
              end
            end
          when 'object'
            next if record.send(property_name)
            if property_value = json[name]
              raise Exception.new("Hash value expected for property #{property_name} but #{property_value.class} found: #{property_value}") unless property_value.is_a?(Hash)
              if property_value['$referenced']
                property_value = property_value.reject { |k, _| k == '$referenced' }
                if (criteria = property_model.where(property_value)).empty?
                  record.instance_variable_set(:@_references, references = {}) unless references = record.instance_variable_get(:@_references)
                  references[property_name] = {model: property_model, criteria: property_value}
                else
                  record.send("#{property_name}=", criteria.first)
                end
              else
                record.send("#{property_name}=", do_parse_json(data_type, property_model, property_value, options, property_schema))
              end
            end
          else
            next if record.send(property_name)
            if property_value = json[name]
              raise Exception.new("Simple value expected for property #{property_name} but #{property_value.class} found: #{property_value}") if property_value.is_a?(Hash) || property_value.is_a?(Array)
              record.send("#{property_name}=", property_value)
            end
          end
        end

        if (sub_model = json_schema['sub_schema']) &&
            (sub_model = json.send(:eval, sub_model)) &&
            (data_type = data_type.find_data_type(sub_model)) &&
            (sub_model = data_type.records_model) &&
            sub_model != model
          sub_record = sub_model.new
          json_schema['properties'].each do |property_name, property_schema|
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

      def do_parse_edi(data_type, model, content, json_schema, start, field_sep, segment_sep, report, record=nil, json=nil, fields=nil, segment=nil, new_record=nil)
        json_schema = data_type.merge_schema(json_schema)
        unless record
          if json_schema['edi'] && seg_id = json_schema['edi']['segment']
            return [nil, start, nil] unless start < content.length && content[start, seg_id.length] == seg_id
            field_sep = content[start + seg_id.length] unless field_sep
            #raise Exception.new("Invalid field separator #{field_sep}") unless field_sep == :by_fixed_length || field_sep == content[start + seg_id.length]
            unless segment_sep ||= report[:segment_separator]
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
                next_seg_relation = model.relations.values.detect { |relation| [:has_many, :has_and_belongs_to_many, :embeds_many, :has_one, :embeds_one].include?(relation.macro) }
                if next_seg_relation && (next_seg_schema = json_schema['properties'][next_seg_relation.name.to_s])
                  next_seg_schema = next_seg_schema['items'] if next_seg_schema['type'] == 'array'
                  next_seg_schema = data_type.merge_schema(next_seg_schema)
                  raise Exception.new('Can not infers segment separator without EDI segment metadata in next sub-segment schema') unless next_seg_schema['edi'] && next_seg_id = next_seg_schema['edi']['segment']
                  puts "Inferring segment separator with field separator #{field_sep}..."
                  fields_count = json_schema['properties'].values.count { |property_schema| !%w{object array}.include?(property_schema['type']) && property_schema['$ref'].nil? }
                  cursor = start + seg_id.length + 1
                  while fields_count > 0
                    cursor = content.index(field_sep, cursor) + 1
                    fields_count -= 1
                  end
                  raise Exception.new('Error inferring segment separator') unless next_seg_id && (content[cursor - next_seg_id.length - 1, next_seg_id.length] == next_seg_id)
                  puts "Segment separator inferred: #{segment_sep = content[cursor - next_seg_id.length - 2]}"
                else
                  raise Exception.new('Can not infers segment separator without sub-segment schemas')
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
              fields = (segment = content[start..(start = (content.index(segment_sep, start) || content.length)) - 1]).split(field_sep)
              fields.shift
            end
            unless (start != content.length - 1) && (content[start, segment_sep.length] == segment_sep)
              puts content.length
              puts "Warning!!!"
              start = content.index(segment_sep, start) || start
            end
            start += segment_sep.length
          else
            fields = []
          end
        end
        json ||= {}
        record ||= new_record || model.new
        required = json_schema['required'] || []
        json_schema['properties'].each do |property_name, property_schema|
          next if json[property_name]
          property_schema = data_type.merge_schema(property_schema)
          case property_schema['type']
          when 'array'
            relation = model.reflect_on_association(property_name)
            next unless [:has_many, :has_and_belongs_to_many, :embeds_many].include?(relation.macro)
            property_schema = data_type.merge_schema(property_schema['items'])
            property_model = relation.klass
            property_json = []
            while (sub_segment = do_parse_edi(data_type, property_model, content, property_schema, start, field_sep, segment_sep, report))[0]
              property_json << sub_segment[0]
              (record.send(property_name)) << sub_segment[2]
              start = sub_segment[1]
            end
            json[property_name] = property_json unless property_json.empty?
          when 'object'
            relation = model.reflect_on_association(property_name)
            next unless [:has_one, :embeds_one].include?(relation.macro)
            property_model = relation.klass
            if field = fields.shift #composite field
              property_json = {}
              property_record = property_model.new
              sub_elements = field.split(':')
              property_schema['properties'].each do |key, _|
                if (sub_element = sub_elements.shift) && !sub_element.blank?
                  property_json[key] = sub_element
                  property_record.send("#{key}=", sub_element)
                end
              end
              property_json.empty? ? (property_json = nil) : record.send("#{property_name}=", property_record)
            else
              property_json, start, property_record = do_parse_edi(data_type, property_model, content, property_schema, start, field_sep, segment_sep, report)
              record.send("#{property_name}=", property_record) if property_record
            end
            json[property_name] = property_json if property_json
          else
            if (field = fields.shift) && field.length != 0
              json[property_name] = field
              record.send("#{property_name}=", field)
            end
          end
          return [nil, start, nil] if !json[property_name] && json.empty? && required.include?(property_name)
        end

        if (sub_model = json_schema['sub_schema']) &&
            (sub_model = record.try(:eval, sub_model)) &&
            (data_type = data_type.find_data_type(sub_model)) &&
            (sub_model = data_type.records_model) &&
            sub_model != model
          sub_record = sub_model.new
          json_schema['properties'].each do |property_name, property_schema|
            if value = record.send(property_name)
              sub_record.send("#{property_name}=", value)
              record.send("#{property_name}=", nil)
            end
          end
          json, start, record = do_parse_edi(data_type, sub_model, content, data_type.merged_schema, start, field_sep, segment_sep, report, sub_record, json, fields, segment)
        end

        return [nil, start, nil] if json.empty?

        report[:segments] << [segment, record]

        record.try(:run_after_initialized)
        return [json, start, record]
      end

    end
  end
end