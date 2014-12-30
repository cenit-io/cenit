module EDI
  class Parser

    class << self

      def parse(data_type, content, start=0, field_sep=nil, segment_sep=nil)
        json, start, record = do_parse(data_type, data_type.model, content, data_type.merged_schema, start, field_sep, segment_sep, report={segments: []})
        report[:json] = json
        report[:scan_size] = start
        report[:record] = record
        return report
      end

      private

      def do_parse(data_type, model, content, json_schema, start, field_sep, segment_sep, report, record=nil, json=nil, fields=nil, segment=nil)
        json_schema = data_type.merge_schema(json_schema)
        unless record
          if json_schema['edi'] && seg_id = json_schema['edi']['segment']
            return [nil, start, nil] unless start < content.length && content[start, seg_id.length] == seg_id
            field_sep = content[start + seg_id.length] unless field_sep
            raise Exception.new("Invalid field separator #{field_sep}") unless field_sep == :by_fixed_length || field_sep == content[start + seg_id.length]
            unless segment_sep ||= report[:segment_sep]
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
              report[:segment_sep] = segment_sep
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
        record ||= model.new
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
              while (sub_segment = do_parse(data_type, property_model, content, property_schema, start, field_sep, segment_sep, report))[0]
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
                if property_json.empty?
                  property_json = nil
                else
                  record.send("#{property_name}=", property_record)
                end
              else
                property_json, start, property_record = do_parse(data_type, property_model, content, property_schema, start, field_sep, segment_sep, report)
                record.send("#{property_name}=", property_record) if property_record
              end
              json[property_name] = property_json if property_json
            else
              if (field = fields.shift) && field.length != 0
                json[property_name] = field
                record.send("#{property_name}=", field)
              end
          end
        end

        if (sub_model = json_schema['sub_schema']) &&
            (sub_model = (record.send(:eval, sub_model) rescue nil)) &&
            (data_type = data_type.find_data_type(sub_model)) &&
            (sub_model = data_type.model) &&
            sub_model != model
          sub_record = sub_model.new
          json_schema['properties'].each do |property_name, property_schema|
            if value = record.send(property_name)
              sub_record.send("#{property_name}=", value)
              record.send("#{property_name}=", nil)
            end
          end
          json, start, record = do_parse(data_type, sub_model, content, data_type.merged_schema, start, field_sep, segment_sep, report, sub_record, json, fields, segment)
        end

        return [nil, start, nil] if json.empty?

        report[:segments] << [segment, record]

        return [json, start, record]
      end

    end
  end
end