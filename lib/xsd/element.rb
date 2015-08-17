module Xsd
  class Element < TypedTag
    include BoundedTag
    include RefererTag

    tag 'element'

    def when_simpleType_end(simpleType)
      @type = simpleType.type
    end

    def when_complexType_end(complexType)
      @type = complexType
    end

    def to_json_schema
      return qualify_element(ref).to_json_schema if ref
      json =
        {
          'title' => name.to_title,
          'edi' => {'segment' => name},
          'type' => 'object'
        }
      merge_json =
        if @type
          if @type.is_a?(ComplexType)
            @type.to_json_schema
          else
            {
              'properties' => {
                'value' => @type.to_json_schema.merge('title' => 'Value',
                                                      'xml' => {'content' => true})
              }
            }
          end
        else
          if (type_schema = qualify_type(type_name).to_json_schema)['$ref']
            type_schema = type_schema['$ref']
          end
          {'extends' => type_schema}
        end
      json.merge(merge_json)
    end
  end
end
