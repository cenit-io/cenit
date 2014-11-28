module Xsd
  class Schema < BasicTag

    tag 'xs:schema'

    attr_reader :json_schemas

    def initialize
      @json_schemas = {}
    end

    def when_end_xs_element(element)
      store_tag_schema(element)
    end

    def when_end_xs_simpleType(simpleType)
     store_tag_schema(simpleType)
    end

    def when_end_xs_complexType(complexType)
      store_tag_schema(complexType)
    end

    def store_schema(name, schema)
      name = name.underscore.camelize
      raise Exception.new("name clash: #{name}") if @json_schemas[name]
      @json_schemas[name] = schema
    end

    private

    def store_tag_schema(tag)
      store_schema(tag.name, tag.to_json_schema)
    end
  end
end