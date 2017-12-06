module Edi
  class Parser

    class << self

      def parse_edi(data_type, content, options={}, record=nil)
        start = options[:start] || 0
        content = content.gsub("\r", '')
        segment_sep = "\n" if (segment_sep = options[:segment_separator]) == :new_line
        raise Exception.new("Record model #{record.orm_model} does not match data type model#{data_type.orm_model}") unless record.nil? || record.orm_model == data_type.records_model
        json, start, record = do_parse_edi(data_type, model = data_type.records_model, content, model.schema, start, options[:field_separator], segment_sep, report={ segments: [] }, new_record: record)
        raise Exception.new("Unexpected input at position #{start}: #{content[start, content.length - start <= 10 ? content.length - 1 : 10]}") if start < content.length
        report[:json] = json
        report[:scan_size] = start
        report[:record] = record
        record
      end

      def parse_json(data_type, content, options={}, record=nil, model=nil)
        content = JSON.parse(content) unless content.is_a?(Hash)
        process_options(options)
        do_parse_json(data_type, model || data_type.records_model, content.with_indifferent_access, options, (record && record.orm_model.schema) || (model && model.schema) || data_type.merged_schema, nil, record)
      end

      def parse_xml(data_type, content, options={}, record=nil)
        process_options(options)
        do_parse_xml(data_type, data_type.records_model, content.is_a?(Nokogiri::XML::Element) ? content : Nokogiri::XML(content).root, options, data_type.merged_schema, nil, record)
      end

      private

      def process_options(options)
        p =
          case (p = options.delete(:primary_fields) || options.delete('primary_fields'))
          when Array
            p
          when Enumerable
            p.to_a
          else
            [p]
          end
        s =
          case (s = options[:primary_field] || options.delete('primary_field') || [])
          when Array
            s
          when Enumerable
            s.to_a
          else
            [s]
          end
        options[:primary_field] = s + p
        [:ignore, :reset, :primary_field].each do |opt|
          val = (options[opt] || [])
          val = [val] unless val.is_a?(Enumerable)
          val = val.select { |p| p.is_a?(Symbol) || p.is_a?(String) }.collect(&:to_sym)
          options[opt] = val
        end
      end

      def qualify_name(xml_node)
        ns = (ns = xml_node.namespace) ? ns.href + ':' : ''
        ns + xml_node.name
      end

      def find_record(model, container, container_schema)
        yield(criteria = {})
        if criteria.empty?
          nil
        else
          (container && (Cenit::Utility.find_record(criteria, container) || container.detect { |item| Cenit::Utility.match?(item, criteria) })) ||
            ((container_schema && container_schema['exclusive']) ? nil : Cenit::Utility.find_record(criteria, model))
        end
      end

      def extract_xml_value(xml_element, model, property, property_schema = nil)
        if (property_schema ||= model.property_schema(property))
          name = (property_schema['edi'] && property_schema['edi']['segment']) || property.to_s
          xml_value =
            if property_schema.key?('xml') && property_schema['xml']['attribute']
              xml_element.attributes[name].value
            else
              xml_element.xpath("//#{name}").text
            end
          model.mongo_value(xml_value, property, property_schema)
        end
      end

      def do_parse_xml(data_type, model, element, options, json_schema, record = nil, new_record = nil, enclosed_property = nil, container = nil, container_schema = nil)
        updating = !(record.nil? && new_record.nil?) || options[:add_only]
        json_schema = data_type.merge_schema(json_schema)
        name = json_schema['edi']['segment'] if json_schema['edi']
        name ||= enclosed_property || model.data_type.name
        return unless name == qualify_name(element)
        resetting = options[:reset].collect(&:to_s)
        unless record ||= new_record
          if model && model.modelable?
            primary_field = options.delete(:primary_field) || []
            if primary_field.empty? && !extract_xml_value(element, model, :_id).nil?
              primary_field << :_id
            end
            if primary_field.present?
              record = find_record(model, container, container_schema) do |criteria|
                primary_field.each do |property|
                  if (value = extract_xml_value(element, model, property))
                    criteria[property.to_s] = value
                  end
                end
              end
            end
          end
          if record
            updating = true
            unless model == record.orm_model
              model = record.orm_model
              data_type = model.data_type
              json_schema = model.schema
            end
          else
            updating = false
            (record = model.new).instance_variable_set(:@dynamically_created, true)
          end
        end
        content_property = nil
        if (xml_opts = json_schema['xml']).nil? || (content_property = xml_opts['content_property']).nil?
          model.properties.each do |property|
            next if content_property
            property_model = model.property_model(property)
            property_schema = property_model.schema
            if (xml_opts = property_schema['xml'] || {})
              content_property = property if xml_opts['content']
            end
          end
        end
        element.attribute_nodes.each do |attr|
          if (property = model.property_for(attr.name))
            property_schema = model.property_schema(property)
            next unless property_schema.key?('xml') && property_schema['xml']['attribute']
            next if options[:ignore].include?(property.to_sym) ||
              (updating && ((property == '_id' || primary_field.include?(attr.name.to_sym)) && !record.send(property).nil?))
            value =
              if model.property_model(property).schema['type'] == 'array'
                attr.value.split(' ')
              else
                attr.value
              end
            record.send("#{property}=", value)
          end
        end
        if content_property
          content =
            if element.children.empty?
              element.content
            else
              element.namespaces.each { |ns, value| element[ns] = value }
              Hash.from_xml(element.to_xml).values.first
            end
          record.send("#{content_property}=", content)
        else
          associations = {}
          elements = element.element_children.to_a
          elements.each do |sub_element|
            if (property = model.property_for(qualify_name(sub_element)))
              property_schema = model.property_schema(property)
              next if property_schema.key?('xml') && property_schema['xml']['attribute'] ||
                options[:ignore].include?(property.to_sym)
              property_model = model.property_model(property)
              if property_model.modelable?
                persist = property_model.persistable?
                if property_schema['type'] == 'array'
                  if (association_track = associations[property])
                    next unless associations[:kept]
                    sub_values = association_track[:new]
                  else
                    associations[property] = {
                      current: association = record.send(property),
                      kept: kept = (updating || association.blank?)
                    }
                    next unless kept
                    sub_values =
                      if resetting.include?(property) || !options[:add_only]
                        if association.nil?
                          record.send("#{property}=", [])
                          associations[property][:current] = association = record.send(property)
                          nil
                        elsif association.present?
                          []
                        end
                      end
                    associations[property][:new] = sub_values
                  end
                  items_schema = property_model.schema
                  if (sub_record = do_parse_xml(data_type, property_model, sub_element, options, items_schema, nil, nil, property, association, property_schema)) &&
                    (sub_values || association).exclude?(sub_record)
                    (sub_values || association) << sub_record
                  end
                else # type 'object'
                  associations[property] = { kept: kept = (updating || record.send(property).nil?) }
                  next unless kept
                  if (sub_record = do_parse_xml(data_type, property_model, sub_element, options, property_schema, nil, nil, property))
                    record.send("#{property}=", sub_record)
                  end
                end
              else
                next if updating && ((property == '_id' || primary_field.include?(qualify_name(sub_element))) && !record.send(property).nil?)
                unless (property_value = Hash.from_xml(sub_element.to_xml).values.first).nil?
                  record.send("#{property}=", property_value)
                end
              end
            end
          end
          associations.each do |property, association_track|
            next unless (sub_values = association_track[:new])
            record.send("#{property}=", sub_values)
          end
          unless options[:add_only]
            json_schema['properties'].each do |property, property_schema|
              next unless property_schema['type'] == 'object' && !associations.key?(property)
              record.send("#{property}=", nil) if (property_model = model.property_model(property)) && property_model.modelable?
            end
          end
        end
        record.try(:run_after_initialized)
        record.instance_variable_set(:@_edi_parsed, true)
        record
      end

      def do_parse_json(data_type, model, json, options, json_schema, record = nil, new_record = nil, container = nil, container_schema = nil)
        updating = !(record.nil? && new_record.nil?) || options[:add_only]
        (primary_fields = options.delete(:primary_field) || options.delete('primary_field')).present? ||
          (primary_fields = json.is_a?(Hash) && json['_primary']).present? ||
          (primary_fields = [])
        primary_fields = [primary_fields] unless primary_fields.is_a?(Array)
        primary_fields.delete_if { |primary_field| !json.key?(primary_field) }
        if primary_fields.empty? && json.is_a?(Hash)
          primary_fields << ((json.key?('_id') || json.key?(:_id)) ? :_id : :id)
        end
        primary_fields = primary_fields.collect(&:to_sym)
        unless record ||= new_record
          if model && model.modelable?
            record = find_record(model, container, container_schema) do |criteria|
              if json.is_a?(Hash) &&
                options[:ignore].none? { |ignored_field| primary_fields.include?(ignored_field) } &&
                (criterion = Cenit::Utility.deep_remove(json.select { |key, _| primary_fields.include?(key.to_sym) }, '_reference')).size == primary_fields.count
                criteria.merge!(criterion)
              end
            end
            if record
              return record if json['_reference'].to_b
              updating = true
              unless model == record.orm_model
                model = record.orm_model
                data_type = model.data_type
                json_schema = model.schema
              end
            else
              updating = false
              (record = model.new).instance_variable_set(:@dynamically_created, true)
            end
          else
            return json
          end
        end
        json_schema = data_type.merge_schema(json_schema)
        if json.is_a?(Hash)
          resetting = json['_reset'] || []
          resetting = (resetting.is_a?(Enumerable) ? resetting.to_a : [resetting]) + options[:reset].to_a
          resetting = resetting.collect(&:to_s)
          taken_items = Set.new
          phase = 0
          while phase < 2
            json_schema['properties'].each do |property_name, property_schema|
              next if options[:ignore].include?(property_name.to_sym) || (taken_items.size == json.size && !updating)
              property_schema = data_type.merge_schema(property_schema)
              name = property_schema['edi']['segment'] if property_schema['edi']
              name ||= property_name
              name = name.split(':').last if phase > 0
              next if taken_items.include?(name)
              property_model = model.property_model(property_name)
              taken_items << property_name if json.has_key?(name)
              case property_schema['type']
              when 'array'
                association = record.send(property_name)
                next unless updating || association.blank?
                property_value = json[name]
                sub_values =
                  if resetting.include?(property_name) || !options[:add_only]
                    if property_value.nil? || association.nil?
                      record.send("#{property_name}=", [])
                      association = record.send(property_name)
                      nil
                    elsif association.present?
                      []
                    end
                  end
                items_schema = data_type.merge_schema(property_schema['items'] || {})
                if property_value
                  property_value = [property_value] unless property_value.is_a?(Array)
                  persist = property_model && property_model.persistable?
                  property_value.each do |sub_value|
                    next unless sub_value
                    if persist && sub_value['_reference'] && ((sub_value[:id].nil? && sub_value[:_id].nil?) || options[:skip_refs_binding])
                      sub_value = Cenit::Utility.deep_remove(sub_value, '_reference')
                      unless Cenit::Utility.find_record(sub_value, sub_values || [])
                        if (found_value = Cenit::Utility.find_record(sub_value, association))
                          sub_values << found_value if sub_values
                        else
                          unless (references = record.instance_variable_get(:@_references))
                            record.instance_variable_set(:@_references, references = {})
                          end
                          (references[property_name] ||= []) << { model: property_model, criteria: sub_value }
                        end
                      end
                    else
                      sub_value = do_parse_json(data_type, property_model, sub_value, options, items_schema, nil, nil, association, property_schema)
                      unless (sub_values || association).include?(sub_value)
                        (sub_values || association) << sub_value
                      end
                    end
                  end
                  if sub_values
                    record.send("#{property_name}=", sub_values)
                  end
                end
              when 'object'
                next unless updating || !property_model.modelable? || record.send(property_name).nil?
                if (property_value = json[name])
                  if property_model && property_value.is_a?(Hash) && property_value['_reference'] && ((property_value[:id].nil? && property_value[:_id].nil?) || options[:skip_refs_binding])
                    record.send("#{property_name}=", nil)
                    property_value = Cenit::Utility.deep_remove(property_value, '_reference')
                    unless (references = record.instance_variable_get(:@_references))
                      record.instance_variable_set(:@_references, references = {})
                    end
                    references[property_name] = { model: property_model, criteria: property_value }
                  else
                    record.send("#{property_name}=", do_parse_json(data_type, property_model, property_value, options, property_schema))
                  end
                else
                  record.send("#{property_name}=", nil) if property_model && property_model.modelable? && !options[:add_only]
                end
              else
                next if updating && ((property_name == '_id' || primary_fields.include?(name.to_sym)) && !record.send(property_name).nil?)
                unless (property_value = json[name]).nil?
                  record.send("#{property_name}=", property_value)
                end
              end
            end if taken_items.size < json.size
            phase += 1
          end

          if (sub_model = json['_type']) &&
            sub_model.is_a?(String) &&
            (sub_model = sub_model.start_with?('self[') ? (json.send(:eval, sub_model) rescue nil) : sub_model) &&
            (data_type = data_type.find_data_type(sub_model)) &&
            (sub_model = data_type.records_model) &&
            !sub_model.eql?(model)
            sub_record = record.becomes(sub_model)
            record = do_parse_json(data_type, sub_model, json, options, data_type.merged_schema, sub_record)
          end
        else # Simple content or array
          content_property = nil
          property_schema = nil
          if (properties = json_schema['properties'])
            if properties.size == 1
              content_property = properties.keys.first
              property_schema = data_type.merge_schema(properties.values.first)
            else
              properties.each do |property_name, property_schema|
                next if content_property || options[:ignore].include?(property_name.to_sym)
                property_schema = data_type.merge_schema(property_schema)
                if property_schema['xml'] && property_schema['xml']['content']
                  content_property = property_name
                end
              end
            end
          end
          if content_property
            if json.is_a?(Array)
              fail "Can not assign an array as a simple content to #{data_type.name}" unless property_schema['type'] == 'array'
              value = record.send(content_property)
              if updating || value.blank?
                items_schema = data_type.merge_schema(property_schema['items'] || {})
                record.send("#{content_property}=", [])
                association = record.send(content_property)
                property_model = model.property_model(content_property)
                persist = property_model && property_model.persistable?
                json.each do |sub_value|
                  if persist && sub_value['_reference'] && ((sub_value[:id].nil? && sub_value[:_id].nil?) || options[:skip_refs_binding])
                    sub_value = Cenit::Utility.deep_remove(sub_value, '_reference')
                    unless Cenit::Utility.find_record(sub_value, association)
                      unless (references = record.instance_variable_get(:@_references))
                        record.instance_variable_set(:@_references, references = {})
                      end
                      (references[property_name] ||= []) << { model: property_model, criteria: sub_value }
                    end
                  else
                    sub_value = do_parse_json(data_type, property_model, sub_value, options, items_schema, nil, nil, association, property_schema)
                    unless association.include?(sub_value)
                      association << sub_value
                    end
                  end
                end
              end
            else
              if content_property == '_id'
                if (existing = Cenit::Utility.find_record({ id: json }, container))
                  record = existing
                else
                  record.id = json
                end
              else
                record.send("#{content_property}=", json)
              end
            end
          else
            fail "Can not assign #{json} as simple content to #{data_type.name}"
          end
        end
        record.try(:run_after_initialized)
        record.instance_variable_set(:@_edi_parsed, true)
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
              if (next_seg_property = model.properties_schemas.keys.detect { |property| model.property_model?(property) })
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
            if property_schema['type'] == 'array'
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
          sub_record = record.becomes(sub_model)
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