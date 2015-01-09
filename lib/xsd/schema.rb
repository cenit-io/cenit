module Xsd
  class Schema < AttributedTag

    tag 'xs:schema'

    attr_reader :json_schemas

    def initialize(parent, attributes)
      super
      targetNamespace = (attr = attributes.detect { |attr| attr[0] == 'targetNamespace' }) ? attr[1] : nil
      raise Exception.new('Default and target does not match') if (default = @xmlns[:default]) && default != targetNamespace
      @xmlns[:default] = targetNamespace
      @json_schemas = {}
    end

    def when_end_xs_element(element)
      store_tag_schema(:qualify_element, element)
    end

    def when_end_xs_simpleType(simpleType)
     store_tag_schema(:qualify_type, simpleType)
    end

    def when_end_xs_complexType(complexType)
      store_tag_schema(:qualify_type, complexType)
    end

    def store_schema(name, schema)
      raise Exception.new("name clash: #{name}") if @json_schemas[name]
      @json_schemas[name] = schema
    end

    private

    def store_tag_schema(qualify_method, tag)
      store_schema(send(qualify_method, tag.name), tag.to_json_schema)
    end
  end
end