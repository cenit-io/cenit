module Xsd
  class ComplexType < TypedTag
    include AttributeContainerTag

    tag 'complexType'

    attr_reader :container

    def extension_start(attributes = [])
      @base = attributeValue(:base, attributes)
      nil
    end

    def restriction_start(attributes = [])
      @base = attributeValue(:base, attributes)
      @simpleType = SimpleTypeRestriction.new(parent: self, base: @base)
    end

    def attributes
      super + (@simpleType.is_a?(SimpleTypeRestriction) ? @simpleType.attributes : [])
    end

    [Xsd::Sequence, Xsd::Choice, Xsd::All].each do |container_class|
      class_eval("def #{container_class.tag_name}_start(attributes = [])
          #{container_class.to_s}.new(parent: self, attributes: attributes)
        end
      def when_#{container_class.tag_name}_end(container)
          @container = container
      end")
    end

    def to_json_schema
      json_schema = documenting('type' => 'object')
      if name
        json_schema['title'] = name.to_title
      end
      if @base
        if (@base = qualify_type(@base).to_json_schema)['$ref']
          @base = @base['$ref']
        end
        json_schema['extends'] = @base
      end
      inject_attributes(json_schema)
      properties = json_schema['properties'] ||= {}
      required = json_schema['required'] ||= []
      if container
        container_schema = container.to_json_schema
        if container.max_occurs == :unbounded || container.max_occurs > 1 || container.min_occurs > 1
          properties[p = 'value'] =
            {
              'type' => 'array',
              'minItems' => container.min_occurs,
              'items' => container_schema
            }
          properties[p]['maxItems'] = container.max_occurs unless container.max_occurs == :unbounded
          required << p if container.min_occurs.positive?
        else
          container_required = container_schema['required'] || []
          if (container_properties = container_schema['properties']).size == 1
            properties[p = container_properties.keys.first] = container_properties.values.first
            required << p if container_required.include?(p)
          else
            container_properties.each do |property, schema|
              properties[p = property.to_method_name(properties)] = schema
              required << p if container_required.include?(property)
            end
          end
        end
      end
      json_schema.delete('required') unless required.present?
      json_schema
    end
  end
end
