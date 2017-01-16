module Xsd
  class Schema < AttributedTag

    tag 'schema'

    attr_reader :name_prefix
    attr_reader :names

    def initialize(args)
      super
      targetNamespace = (attr = args[:attributes].detect { |attr| attr[0] == 'targetNamespace' }) ? attr[1] : nil
      raise Exception.new('Default and target does not match') if (default = @xmlns[:default]) && default != targetNamespace
      @xmlns[:default] = targetNamespace
      @attributes = []
      @attribute_groups = []
      @elements = []
      @types = []
      @include_uris = Set.new
      @includes = Set.new
      @name_prefix = args[:name_prefix] || ''
      @document = args[:document]
      @names = Set.new
    end

    {
      attribute: :attributes,
      attributeGroup: :attribute_groups,
      element: :elements,
      simpleType: :types,
      complexType: :types
    }.each do |tag_name, store_id|
      class_eval("def when_#{tag_name}_end(#{tag_name})
          @#{store_id} << #{tag_name}
          @names << qualify_with(:#{store_id.to_s.chop}, #{tag_name}.name, false)
        end")
    end

    def include_start(attributes = [])
      if (location = attributeValue(:schemaLocation, attributes))
        @include_uris << location
      else
        raise Exception('include without location')
      end
      nil
    end

    def bind_includes(schema_resolver)
      @include_uris.each do |uri|
        if (schema = schema_resolver.schema_for(document.uri, uri))
          @includes << schema
        else
          raise IncludeMissingException.new("includes undefined schema #{uri}")
        end
      end
    end

    def included?(qualified_name, visited = Set.new)
      return false if visited.include?(self)
      visited << self
      return true if names.include?(qualified_name)
      @includes.each { |schema| return true if schema.included?(qualified_name, visited) }
      false
    end

    def json_schemas
      schemas = {}
      {
        attribute: @attributes,
        attribute_group: @attribute_groups,
        type: @types,
        element: @elements,
      }.each do |qualify_method, store|
        store.each do |tag|
          name = qualify_with(qualify_method, tag.name)
          raise Exception.new("name clash: #{name}") if schemas[name]
          schemas[name] = tag.to_json_schema
        end
      end
      schemas
    end
  end
end