module Xsd
  class Attribute < TypedTag
    include RefererTag

    tag 'attribute'

    attr_reader :use

    def initialize(args)
      super
      @use = attributeValue(:use, args[:attributes])
    end

    def required?
      use == 'required'
    end

    def when_simpleType_end(simpleType)
      if type = simpleType.try(:type)
        @type = type
      end
    end

    def eql?(obj)
      obj.class == Attribute && obj.name == name
    end

    def type
      @type ? @type : type_name
    end

    def to_json_schema
      return documenting(qualify_attribute(ref).to_json_schema) if ref
      if (schema_type = type).is_a?(String)
        schema_type = qualify_type(schema_type)
      end
      schema_type.to_json_schema.merge(documenting('title' => name.to_title, 'xml' => { 'attribute' => true }))
    end

  end
end
