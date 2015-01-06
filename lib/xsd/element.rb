module Xsd
  class Element < TypedTag

    tag 'xs:element'

    attr_accessor :max_occurs
    attr_accessor :min_occurs

    def initialize(parent, attributes)
      super
      _, max_occurs = attributes.detect { |a| a[0] == 'maxOccurs' }
      @max_occurs = max_occurs ? max_occurs.to_i : 1
      _, min_occurs = attributes.detect { |a| a[0] == 'minOccurs' }
      @min_occurs = min_occurs ? min_occurs.to_i : 1
    end

    def when_end_xs_simpleType(simpleType)
      @type = simpleType.type
    end

    def when_end_xs_complexType(complexType)
      @type = complexType
    end

    def to_json_schema
      json = {'title' => name.to_title, 'type' => 'object'}
      if @type
        merge_json = @type.is_a?(ComplexType) ? @type.to_json_schema : {'properties' => {'value' => @type.to_json_schema}}
      else
        merge_json = {'properties' => {'value' => qualify_type(type_name).to_json_schema}}
      end
      json.merge(merge_json)
    end
  end
end
