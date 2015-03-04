module Xsd
  class ComplexType < TypedTag

    tag 'complexType'

    attr_reader :attributes
    attr_reader :container

    def initialize(parent, attributes)
      super
      @attributes = []
    end

    def extension_start(attributes = [])
      _, @base = attributes.detect { |a| a[0] == 'base' }
      if (@base = qualify_type(@base).to_json_schema)['$ref']
        @base = @base['$ref']
      end
      #@attributes << Xsd::Attribute.new(self, [%w{name value}, ['type', base], %w{use required}])
      nil
    end

    def attribute_start(attributes = [])
      @attributes << (attr = Xsd::Attribute.new(self, attributes))
      attr
    end

    [Xsd::Sequence, Xsd::Choice, Xsd::All].each do |container_class|
      class_eval("def #{container_class.tag_name}_start(attributes = [])
          #{container_class.to_s}.new(self, attributes)
        end
      def when_#{container_class.tag_name}_end(container)
          @container = container
      end")
    end

    def to_json_schema
      json = {'type' => 'object'}
      json['title'] = name.to_title if name
      json['extends'] = @base if @base
      json['properties'] = properties = {}
      enum = 0
      required = []
      attributes.each do |a|
        if (type = a.type).is_a?(String)
          type = qualify_type(type)
        end
        properties[p = "attribute_#{enum += 1}"] = type.to_json_schema.merge('title' => a.name.to_title,
                                                                             'xml' => {'attribute' => true},
                                                                             'edi' => {'segment' => a.name})
        required << p if a.required?
      end
      enum = 0
      if container
        container_schema = container.to_json_schema
        if container.max_occurs == :unbounded || container.max_occurs > 1 || container.min_occurs > 1
          properties[p = 'value'] = {'type' => 'array',
                                     'minItems' => container.min_occurs,
                                     'items' => properties[p]}
          properties[p]['maxItems'] = container.max_occurs unless container.max_occurs == :unbounded
          required << p if container.min_occurs > 0
        else
          container_required = container_schema['required'] || []
          if (container_properties = container_schema['properties']).size == 1
            properties[p = 'value'] = container_properties.values.first
            required << p if container_required.include?(container_properties.keys.first)
          else
            container_properties.each do |property, schema|
              properties[p = "property_#{enum += 1}"] = schema
              required << p if container_required.include?(property)
            end
          end
        end
      end
      json['required'] = required if required.present?
      json
    end
  end
end
