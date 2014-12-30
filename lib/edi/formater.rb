module EDI
  module Formatter

    def to_edi(options={})
      unless options[:field_separator]
        options[:field_separator] = '*'
      end
      record_to_edi(data_type = self.data_type, options, JSON.parse(data_type.schema), self, output =[])
      output.join("\r\n")
    end

    private

    def record_to_edi(data_type, options, schema, record, output)
      return unless record
      if schema['edi']
        segment = schema['edi']['segment'] || ''
      else
        header = segment = (schema['title'] || '')
      end
      schema['properties'].each do |property_name, property_schema|
        property_schema = data_type.merge_schema(property_schema)
        case property_schema['type']
          when 'array'
            relation = record.reflect_on_association(property_name)
            next unless [:has_many, :has_and_belongs_to_many, :embeds_many].include?(relation.macro)
            property_schema = data_type.merge_schema(property_schema['items'])
            record.send(property_name).each do |sub_record|
              record_to_edi(data_type, options, property_schema, sub_record, output)
            end
          when 'object'
            relation = record.reflect_on_association(property_name)
            next unless [:has_one, :embeds_one].include?(relation.macro)
            record_to_edi(data_type, options, property_schema, record.send(property_name), output)
          else
            if value = record.send(property_name)
              value = value.to_s
            else
              unless value = property_schema['default']
                value = ''
              end
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
      output << segment unless segment == header
    end
  end
end