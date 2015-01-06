module Xsd
  class ComplexType < TypedTag

    tag 'xs:complexType'

    attr_reader :attributes
    attr_reader :container

    def initialize(parent, attributes)
      super
      @attributes = []
    end

    def start_xs_extension(attributes = [])
      _, base = attributes.detect { |a| a[0] == 'base' }
      @attributes << Xsd::Attribute.new(self, [%w{name value}, ['type', base], %w{use required}])
      nil
    end

    def start_xs_attribute(attributes = [])
      @attributes << (attr = Xsd::Attribute.new(self, attributes))
      return attr
    end

    %w{xs:sequence xs:choice xs:all}.each do |container_tag|
      class_eval("def start_#{container_tag.gsub(':', '_')}(attributes = [])
          return Container.new(self, attributes, '#{container_tag}')
      end
      def when_end_#{container_tag.gsub(':', '_')}(container)
          @container = container
      end")
    end

    def to_json_schema
      json = {'type' => 'object'}
      json['title'] = name.to_title if name
      json['properties'] = properties = {}
      required = []
      attributes.each do |a|
        if (type = a.type).is_a?(String)
          type = qualify_type(type)
        end
        properties[a.name] = type.to_json_schema
        required << a.name if a.required?
      end
      if container
        container.do_product
        container.elements.each do |e|
          if e.max_occurs == :unbounded || e.max_occurs > 0
            properties[e.name] = e.max_occurs == 1 ? e.to_json_schema : {'type' => 'array', 'items' => e.to_json_schema}
          end
        end
      end
      json['required'] = required unless required.empty?
      return json
    end
  end
end
