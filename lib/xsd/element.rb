module Xsd
  class Element < TypedTag

    tag 'element'

    attr_accessor :max_occurs
    attr_accessor :min_occurs

    def initialize(parent, attributes)
      super
      _, max_occurs = attributes.detect { |a| a[0] == 'maxOccurs' }
      @max_occurs = max_occurs ? max_occurs.to_i : 1
      _, min_occurs = attributes.detect { |a| a[0] == 'minOccurs' }
      @min_occurs = min_occurs ? min_occurs.to_i : 1
    end

    def when_simpleType_end(simpleType)
      @type = simpleType.type
    end

    def when_complexType_end(complexType)
      @type = complexType
    end

    def to_json_schema
      json = {'title' => name.to_title, 'type' => 'object', 'edi' => {'segment' => name}}
      if @type
        merge_json = if @type.is_a?(ComplexType)
                       @type.to_json_schema
                     else
                       {'properties' => {'value' => @type.to_json_schema.merge('title' => 'Value')}}
                     end
      else
        if (type_schema = qualify_type(type_name).to_json_schema)['$ref']
          type_schema = type_schema['$ref']
        end
        merge_json = {'extends' => type_schema}
      end
      json.merge(merge_json)
    end
  end
end
