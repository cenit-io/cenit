module Xsd
  class Element < TypedTag

    tag 'element'

    attr_accessor :max_occurs
    attr_accessor :min_occurs

    def initialize(parent, attributes)
      super
      _, max_occurs = attributes.detect { |a| a[0] == 'maxOccurs' }
      @max_occurs =
          if max_occurs
            max_occurs == 'unbounded' ? :unbounded : max_occurs.to_i
          else
            1
          end
      _, min_occurs = attributes.detect { |a| a[0] == 'minOccurs' }
      @min_occurs =
          if min_occurs
            min_occurs == 'unbounded' ? 0 : min_occurs.to_i
          else
            1
          end
      _, @ref = attributes.detect { |a| a[0] == 'ref' }
    end

    def when_simpleType_end(simpleType)
      @type = simpleType.type
    end

    def when_complexType_end(complexType)
      @type = complexType
    end

    def to_json_schema
      return qualify_element(@ref).to_json_schema if @ref
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
