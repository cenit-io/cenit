module Xsd
  class AttributeGroup < NamedTag
    include RefererTag
    include AttributeContainerTag

    tag 'attributeGroup'

    def to_json_schema
      return qualify_attribute_group(ref).to_json_schema if ref
      json_schema = {'type' => 'object'}
      inject_attributes(json_schema)
    end
  end
end