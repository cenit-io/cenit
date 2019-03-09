module Xsd
  class Container < AttributedTag
    include BoundedTag

    attr_reader :elements

    def initialize(args)
      super
      @elements = []
    end

    def when_element_end(element)
      @elements << element
    end

    %w{sequence choice all}.each do |container_tag|
      class_eval("def #{container_tag}_start(attributes = [])
          Xsd::#{container_tag.capitalize}.new(parent: self, attributes: attributes)
        end
      def when_#{container_tag}_end(container)
        @elements << container
      end")
    end

    def any_start(attributes = [])
      @elements << Xsd::Any.new(parent: self, attributes: attributes)
      nil
    end

    def to_json_schema
      json = documenting('type' => 'object', 'title' => tag_name.to_title)
      json['properties'] = properties = {}
      required = []
      if max_occurs == :unbounded || max_occurs.positive? || min_occurs > 1
        elements.each do |element|
          element_schema = element.to_json_schema
          if element.max_occurs == :unbounded || element.max_occurs > 1 || element.min_occurs > 1
            plural_title = (element_schema['title'] || element.name || element.try(:nice_name) || element.tag_name).to_title.pluralize
            p = (element.name || element_schema['title'] || element.try(:nice_name) || element.tag_name).pluralize.to_method_name(properties)
            properties[p] = { 'title' => "List of #{plural_title}",
                              'type' => 'array',
                              'minItems' => element.min_occurs,
                              'items' => element_schema }
            properties[p]['maxItems'] = element.max_occurs unless element.max_occurs == :unbounded
            required << p if element.min_occurs.positive?
          elsif element.is_a?(Container)
            container_required = element_schema['required'] || []
            element_schema['properties'].each do |property, schema|
              properties[p = property.to_method_name(properties)] = schema
              required << p if container_required.include?(property)
            end
          else
            p = (element.name || element_schema['title'] || element.try(:nice_name) || element.tag_name).to_method_name(properties)
            properties[p] = element_schema
          end
        end
      end
      json['required'] = required if required.present?
      json
    end
  end
end
