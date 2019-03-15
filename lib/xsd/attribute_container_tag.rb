module Xsd
  module AttributeContainerTag
    attr_reader :attributes

    def initialize_attribute_container_tag(args)
      @attributes = []
    end

    def attribute_start(attributes = [])
      @attributes << (attr = Xsd::Attribute.new(parent: self, attributes: attributes))
      attr
    end

    def attributeGroup_start(attributes = [])
      @attributes << (attr = Xsd::AttributeGroup.new(parent: self, attributes: attributes))
      attr
    end

    def inject_attributes(json_schema)
      refs = json_schema['$ref'] ||= nil
      properties = json_schema['properties'] ||= {}
      attributes.each do |a|
        if a.is_a?(Xsd::AttributeGroup)
          ref = qualify_attribute_group(a.ref)
          if refs
            refs = json_schema['$ref'] = [refs] unless refs.is_a?(Array)
            refs << ref
          else
            json_schema['$ref'] = refs = ref
          end
        else
          properties[a.name] = a.to_json_schema
          (json_schema['required'] ||= []) << a.name if a.required?
        end
      end
      json_schema.delete('$ref') if refs.nil?
      json_schema
    end
  end
end