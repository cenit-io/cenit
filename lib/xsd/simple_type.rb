module Xsd
  class SimpleType < NamedTag

    tag 'simpleType'

    attr_reader :type

    def restriction_start(attributes = [])
      SimpleTypeRestriction.new(parent: self, base: attributeValue(:base, attributes))
    end

    def list_start(attributes = [])
      SimpleTypeList.new(parent: self, item_type: attributeValue(:itemType, attributes))
    end

    def union_start(attributes = [])
      memberTypes = attributeValue(:memberTypes, attributes)
      memberTypes = memberTypes.split(' ') if memberTypes
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
