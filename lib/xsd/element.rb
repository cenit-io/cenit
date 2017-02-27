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
      return documenting(qualify_element(ref).to_json_schema) if ref
      json_schema =
        {
          'title' => name.to_title,
          'edi' => { 'segment' => qualify(name) },
          'xml' => { 'namespace' => xmlns(:default), 'content_property' => false },
          'type' => 'object'
        }
      merge_json =
        if @type || type_name.nil?
          if @type.is_a?(ComplexType)
            @type.to_json_schema
          else
            {
              'properties' => {
                'value' => @type.to_json_schema.merge('title' => 'Value',
                                                      'xml' => { 'content' => true })
              },
              'xml' => { 'content_property' => 'value' }
            }
          end
        else
          if (type_schema = qualify_type(type_name).to_json_schema)['$ref']
            type_schema = type_schema['$ref']
          end
          { 'extends' => type_schema }
        end
      documenting(json_schema.deep_merge(merge_json))
    end

    def nice_name
      if ref
        ref.split(':').last
      else
        tag_name
      end
    end
  end
end
