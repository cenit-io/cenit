module Xsd
  class SimpleType < NamedTag

    tag 'simpleType'

    attr_reader :type

    def restriction_start(attributes = [])
      base = attributeValue(:base, attributes)
      SimpleTypeRestriction.new(parent: self, base: base)
    end

    def list_start(attributes = [])
      itemType = attributeValue(:itemType, attributes)
      itemType = qualify_type(itemType) if itemType
      SimpleTypeList.new(parent: self, item_type: itemType)
    end

    def union_start(attributes = [])
      memberTypes = attributeValue(:memberTypes, attributes)
      memberTypes = memberTypes.split(' ').collect { |type| qualify_type(type) } if memberTypes
      SimpleTypeUnion.new(parent: self, types: memberTypes)
    end

    def when_restriction_end(restriction)
      @type = restriction
    end

    def when_list_end(list)
      @type = list
    end

    def when_union_end(union)
      @type = union
    end

    def to_json_schema
      (name ? {'title' => name.to_title} : {}).merge(type.to_json_schema)
    end
  end
end
