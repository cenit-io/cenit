module Xsd
  class Schema < AttributedTag

    tag 'schema'

    attr_reader :json_schemas

    def initialize(parent, attributes)
      super
      targetNamespace = (attr = attributes.detect { |attr| attr[0] == 'targetNamespace' }) ? attr[1] : nil
      raise Exception.new('Default and target does not match') if (default = @xmlns[:default]) && default != targetNamespace
      @xmlns[:default] = targetNamespace
      @json_schemas = {}
    end

    {element: :qualify_element,
     simpleType: :qualify_type,
     complexType: :qualify_type}.each do |tag_name, qualify_method|
      class_eval("def when_#{tag_name}_end(#{tag_name})
          store_tag_schema(:#{qualify_method}, #{tag_name})
        end")
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