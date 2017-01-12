module Xsd
  class AttributeGroup < NamedTag
    include RefererTag
    include AttributeContainerTag

    tag 'attributeGroup'

    def to_json_schema
      return documenting(qualify_attribute_group(ref).to_json_schema) if ref
      json_schema = documenting('type' => 'object')
      inject_attributes(json_schema)
    end
  end
end