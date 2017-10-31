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

    def default_hash(options={})
      prepare_options(options)
      max_entries = options[:max_entries].to_i
      max_entries = nil if max_entries == 0
      hash = record_to_hash(self, options, options.delete(:reference), nil, max_entries)
      options.delete(:stack)
      hash = { self.orm_model.data_type.slug => hash } if options[:include_root]
      hash
    end

    def to_hash(options={})
      default_hash(options)
    end

    def to_json(options={})
      hash = to_hash(options)
      options[:pretty] ? JSON.pretty_generate(hash) : hash.to_json
    end

    def share_hash(options = {})
      if self.class.respond_to?(:share_options)
        options =
          begin
            options.reverse_merge(self.class.share_options)
          rescue Exception
            options
          end
      else
        options = options.reverse_merge(
          ignore: [:id],
          include_blanks: true,
          protected: true,
          polymorphic: true
        )
      end
      to_hash(options)
    end

    def share_json(options={})
      hash = share_hash(options)
      options[:pretty] ? JSON.pretty_generate(hash) : hash.to_json
    end

    def to_xml_element(options = {})
      prepare_options(options)
      unless (xml_doc = options[:xml_doc])
        options[:xml_doc] = xml_doc = Nokogiri::XML::Document.new
      end
      element = record_to_xml_element(data_type = self.orm_model.data_type, self.orm_model.schema, self, xml_doc, nil, options, namespaces = {})
      namespaces.each do |ns, xmlns|
        if xmlns.empty?
          element['xmlns'] = ns unless ns.blank?
        else
          element["xmlns:#{xmlns}"] = ns
        end
      end
      element
    end

    def to_xml(options = {})
      element = to_xml_element(options)
      options[:xml_doc] << element
      options[:xml_doc].to_xml(options)
    end

    alias_method :inspect_json, :to_hash

    private

    def prepare_options(options)
      include_id = options[:include_id]
      [:ignore, :only, :embedding, :inspecting, :including].each do |option|
        value = (options[option] || [])
        value = [value] unless value.is_a?(Enumerable)
        value = value.select { |p| p.is_a?(Symbol) || p.is_a?(String) }.collect(&:to_sym)
        options[option] = value
        include_id ||= (value.include?(:id) || value.include?(:_id)) if include_id.nil? && option != :ignore
      end
      [:only].each { |option| options.delete(option) if options[option].empty? }
      options[:inspected_records] = Set.new
      options[:stack] = []
      options[:include_id] = include_id.respond_to?(:call) ? include_id : include_id.to_b
    end

    def split_name(name)
      name = (tokens = name.split(':')).pop
      [tokens.join(':'), name]
    end

    def ns_prefix_for(ns, namespaces, preferred = nil)
      letters = true
      ns = preferred || ns.split(':').last.split('/').last.underscore.split('_').collect { |token| (letters &&= token[0] =~ /[[:alpha:]]/) ? token[0] : '' }.join
      ns = 'ns' if ns.blank?
      if namespaces.values.include?(ns)
        i = 1
        while namespaces.values.include?(nns = ns + i.to_s)
          i += 1
        end
        ns = nns
      end
      ns
    end

    def record_to_xml_element(data_type, schema, record, xml_doc, enclosed_property_name, options, namespaces)
      return unless record
      if Cenit::Utility.json_object?(record)
        return Nokogiri::XML({ enclosed_property_name => record }.to_xml(dasherize: false)).root.first_element_child
      end

      if schema['xml'] && (xmlnss = schema['xml']['xmlns']).is_a?(Hash)
        xmlnss.each do |ns, xmlns|
          namespaces[ns] = ns_prefix_for(ns, namespaces, xmlns) unless namespaces.has_key?(ns)
        end
      end

      element_name = schema['edi']['segment'] if schema['edi']
      element_name ||= enclosed_property_name || record.orm_model.data_type.name
      ns, element_name = split_name(element_name)
      xmlns = ''
      unless ns.empty? || (xmlns = namespaces[ns])
        xmlns = namespaces[ns] =
          if namespaces.values.include?('')
            ns_prefix_for(ns, namespaces)
          else
            ''
          end
      end
      element_name = xmlns.empty? ? element_name : xmlns + ':' + element_name

      required = schema['required'] || []
      attr = {}
      elements = []
      content = nil
      content_property = nil
      record.orm_model.properties_schemas.each do |property_name, property_schema|
        property_schema = data_type.merge_schema(property_schema)
        name = property_schema['edi']['segment'] if property_schema['edi']
        name ||= property_name
        property_model = record.orm_model.property_model(property_name)
        if (inspecting = options[:inspecting].present?) #TODO Factorize for all format formatting
          next unless (property_model || inspecting.include?(name.to_sym))
        else
          next if property_schema['virtual'] ||
            ((property_schema['edi'] || {})['discard'] && !(included_anyway = options[:including_discards])) ||
            options[:ignore].include?(name.to_sym) ||
            (options[:only] && !options[:only].include?(name.to_sym) && !included_anyway)
        end
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
                elements << record_to_xml_element(data_type, property_schema, sub_record, xml_doc, nil, options, namespaces)
              end
            end if property_value
            unless json_objects.empty?
              elements << Nokogiri::XML({ property_name => json_objects }.to_xml(dasherize: false)).root.first_element_child
            end
          else
            elements << Nokogiri::XML({ name => property_value }.to_xml(dasherize: false)).root.first_element_child
          end
        when 'object'
          if property_model && property_model.modelable?
            elements << record_to_xml_element(data_type, property_schema, record.send(property_name), xml_doc, nil, options, namespaces)
          else
            elements << Nokogiri::XML({ name => record.send(property_name) }.to_xml(dasherize: false)).root.first_element_child
          end
        else
          value = property_schema['default'] if (value = record.send(property_name)).nil?
          unless value.nil?
            xml_opts = property_schema['xml'] || {}
            if xml_opts['attribute']
              attr[name] = value if !value.nil? || options[:with_blanks] || required.include?(property_name)
            elsif xml_opts['content']
              if content.nil?
                content = value
                content_property = property_name
              else
                raise Exception.new("More than one content property found: '#{content_property}' and '#{property_name}'")
              end
            else
              elements << Nokogiri::XML({ name => value }.to_xml(dasherize: false)).root.first_element_child
            end
          end
        end
      end
      element = xml_doc.create_element(element_name, attr)
      if elements.empty?
        content =
          case content
          when NilClass
            []
          when Hash
            Nokogiri::XML(content.to_xml).root.element_children
          else
            [json_value(content, options).to_s]
          end
        content.each { |e| element << e }
      else
        raise Exception.new("Incompatible content property ('#{content_property}') in presence of complex content") if content_property
        elements.each { |e| element << e if e }
      end
      element
    end

    def record_to_hash(record, options = {}, referenced = false, enclosed_model = nil, max_entries = nil)
      return record if Cenit::Utility.json_object?(record)
      model =
        begin
          record.orm_model
        rescue
          nil
        end
      return nil unless model
      schema = model.schema
      key_properties =
        if (key_properties = schema['referenced_by'])
          key_properties.dup
        else
          []
        end
      json =
        if key_properties.present?
          if referenced
            { '_reference' => true }
          else
            { '_primary' => key_properties }
          end
        else
          referenced = false
          {}
        end
      unless referenced
        return nil if options[:inspected_records].include?(record) || options[:stack].include?(record)
        options[:inspected_records] << record
      end
      options[:stack] << record
      if (include_id = options[:include_id]).respond_to?(:call)
        include_id = include_id.call(record)
      end
      if include_id
        entries = do_store(json, 'id', record.id, options)
        max_entries -= entries if max_entries
      end
      content_property = nil
      model.stored_properties_on(record).each do |property_name|
        break if max_entries && max_entries < 1
        if (protected = (model.schema['protected'] || []).include?(property_name)) && options[:protected]
          key_properties.delete(property_name)
          next
        end
        property_schema = model.property_schema(property_name)
        property_model = model.property_model(property_name)
        name = property_schema['edi']['segment'] if property_schema['edi']
        name ||= property_name
        if property_schema['type'] != 'object' && (schema['properties'].size == 1 || (property_schema['xml'] && property_schema['xml']['content']))
          content_property = name
        end
        can_be_referenced = !(options[:embedding_all] || options[:embedding].include?(name.to_sym))
        if (inspecting = options[:inspecting].present?)
          unless (property_model || options[:inspecting].include?(name.to_sym)) && (!referenced || key_properties.include?(property_name))
            key_properties.delete(property_name)
            next
          end
        else
          if property_schema['virtual'] ||
            ((property_schema['edi'] || {})['discard'] && !(included_anyway = options[:including_discards] || options[:including].include?(property_name))) ||
            (can_be_referenced && referenced && !key_properties.include?(property_name)) ||
            options[:ignore].include?(name.to_sym) ||
            (options[:only].present? && options[:only].exclude?(name.to_sym) && !included_anyway)
            key_properties.delete(property_name)
            next
          end
        end
        if name != property_name
          key_properties.each_with_index do |p, i|
            if p == property_name
              key_properties[i] = name
              break
            end
          end
        end
        case property_schema['type']
        when 'array'
          referenced_items = can_be_referenced && property_schema['referenced'] && !property_schema['export_embedded']
          if (value = record.send(property_name))
            next if max_entries && value.size > max_entries
            sub_max_entries = max_entries && (max_entries - value.size)
            sub_max_entries = 1 unless sub_max_entries.nil? || sub_max_entries > 0
            new_value = []
            value.each do |sub_record|
              next if inspecting && (scope = options[:inspect_scope]) && !scope.include?(sub_record)
              new_value << record_to_hash(sub_record, options, referenced_items, property_model, sub_max_entries)
            end
          else
            new_value = nil
            sub_max_entries = max_entries
          end
          do_store(json, name, new_value, options, key_properties.include?(property_name))
          max_entries = sub_max_entries
        when 'object'
          sub_record = record.send(property_name)
          next if inspecting && (scope = options[:inspect_scope]) && !scope.include?(sub_record)
          value = record_to_hash(sub_record, options, can_be_referenced && property_schema['referenced'] && !property_schema['export_embedded'], property_model, max_entries && max_entries - 1)
          entries = do_store(json, name, value, options, key_properties.include?(property_name))
          max_entries -= entries if max_entries
        else
          begin
            if (value = record.send(property_name)).nil?
              value = (protected ? nil : record[property_name])
            end
          rescue
            value = nil
          end
          if value.nil?
            value = property_schema['default']
          end
          entries = do_store(json, name, value, options, key_properties.include?(property_name)) #TODO Default values should came from record attributes
          max_entries -= entries if max_entries
        end
      end
      if (options[:inspecting].include?(:_type) ||
        options[:including].include?(:_type) ||
        (enclosed_model && !record.orm_model.eql?(enclosed_model)) ||
        (options[:polymorphic] && record.orm_model.hereditary?)) && !json['_reference'] && !options[:ignore].include?(:_type) && (!options[:only] || options[:only].include?(:_type))
        json['_type'] = model.to_s
      end
      options[:stack].pop
      if content_property && json.size == 1 && options[:inline_content] && json.has_key?(content_property) && !json[content_property].is_a?(Hash)
        json[content_property]
      else
        if json.key?('id')
          json.delete('_primary')
        elsif key_properties.include?('id')
          key_properties.delete('id')
          json.delete('_primary') if key_properties.empty?
        end
        json
      end
    end

    def do_store(json, key, value, options, store_anyway = false)
      if options[:nqnames]
        key = key.to_s.split(':').last
      end
      if value.nil?
        if store_anyway || options[:include_null]
          k = json.key?(key) ? 0 : 1
          json[key] = nil
          k
        else
          0
        end
      elsif value.is_a?(Array) || value.is_a?(Hash)
        if store_anyway || value.present? || options[:include_blanks] || options[:include_empty]
          k = json.key?(key) ? 0 : value.size
          json[key] = value
          k
        else
          0
        end
      else
        value = value.to_s if [BSON::ObjectId, Symbol].any? { |klass| value.is_a?(klass) }
        value = json_value(value, options)
        if store_anyway || !(value.nil? || value.try(:empty?)) || options[:include_blanks] #TODO String blanks!
          k = json.key?(key) ? 0 : 1
          json[key] = value
          k
        else
          0
        end
      end
    end

    def json_value(value, options)
      case value
      when Time
        value.strftime('%H:%M:%S')
      when Date, DateTime
        value.to_s
      else
        if Cenit::Utility.json_object?(value)
          value
        else
          options = options.dup
          if (hash = value.try(:to_hash, options))
            hash
          elsif (json = value.try(:to_json, options))
            JSON.parse(json.to_s) rescue json.to_s
          else
            value.to_s
          end
        end
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
            if sub_values = record.send(property_name)
              property_schema = data_type.merge_schema(property_schema['items'])
              sub_values.each do |sub_record|
                output.concat(record_to_edi(data_type, options, property_schema, sub_record, property_name))
              end
            end
          else
            if (sub_record = record.send(property_name))
              if property_schema['edi'] && property_schema['edi']['inline']
                value = []
                property_model.properties_schemas.each do |sub_property_name, sub_property_schema|
                  value << edi_value(sub_record, sub_property_name, sub_property_schema, sub_record.orm_model.property_model(sub_property_name), options)
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
      if (value = record[property_name]).nil?
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
          if auto_fill[0] == 'R'
            value += auto_fill[1] until value.length == max_len
          else #should be 'L'
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
