module Xsd
  class Schema < AttributedTag

    tag 'schema'

    attr_reader :name_prefix

    def initialize(args)
      super
      targetNamespace = (attr = args[:attributes].detect { |attr| attr[0] == 'targetNamespace' }) ? attr[1] : nil
      raise Exception.new('Default and target does not match') if (default = @xmlns[:default]) && default != targetNamespace
      @xmlns[:default] = targetNamespace
      @attributes = []
      @attribute_groups = []
      @elements = []
      @types = []
      @includes = Set.new
      @name_prefix = args[:name_prefix] || ''
      @document = args[:document]
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
        end")
    end

    def include_start(attributes = [])
      location = attributeValue(:schemaLocation, attributes)
      raise Exception('include without location') unless location
      abs_location = Cenit::Utility.abs_uri(document.uri, location)
      if schema = Setup::Schema.where(uri: abs_location).first
        schema.data_types.each { |data_type| @includes.add(data_type.name) }
      else
        msg = "includes undefined schema #{location}"
        msg += " (#{abs_location})" if abs_location != location
        raise IncludeMissingException.new(msg)
      end
      nil
    end

    def included?(qualified_name)
      @includes.include?(qualified_name)
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