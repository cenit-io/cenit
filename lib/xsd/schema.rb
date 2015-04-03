module Xsd
  class Schema < AttributedTag

    tag 'schema'

    attr_reader :name_prefix

    def initialize(parent, attributes, name_prefix='')
      super(parent, attributes)
      targetNamespace = (attr = attributes.detect { |attr| attr[0] == 'targetNamespace' }) ? attr[1] : nil
      raise Exception.new('Default and target does not match') if (default = @xmlns[:default]) && default != targetNamespace
      @xmlns[:default] = targetNamespace
      @elements = []
      @types = []
      @includes = Set.new
      @name_prefix = name_prefix || ''
    end

    {element: :elements,
     simpleType: :types,
     complexType: :types}.each do |tag_name, store_id|
      class_eval("def when_#{tag_name}_end(#{tag_name})
          @#{store_id} << #{tag_name}
        end")
    end

    def include_start(attributes = [])
      _, location = attributes.detect { |a| a[0] == 'schemaLocation' }
      raise Exception('include without location') unless location
      if schema = Setup::Schema.where(uri: location).first
        schema.data_types.each { |data_type| @includes.add(data_type.name) }
      else
        raise IncludeMissingException.new("includes undefined schema #{location}")
      end
      nil
    end

    def included?(qualified_name)
      @includes.include?(qualified_name)
    end

    def json_schemas
      schemas = {}
      {qualify_type: @types, qualify_element: @elements}.each do |qualify_method, store|
        store.each do |tag|
          name = send(qualify_method, tag.name)
          raise Exception.new("name clash: #{name}") if schemas[name]
          schemas[name] = tag.to_json_schema
        end
      end
      schemas
    end
  end

  class IncludeMissingException < Exception
  end
end