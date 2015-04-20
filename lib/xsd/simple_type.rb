module Xsd
  class SimpleType < NamedTag

    tag 'simpleType'

    attr_reader :type

    def restriction_start(attributes = [])
      _, base = attributes.detect { |a| a[0] == 'base' }
      SimpleTypeRestriction.new(self, base)
    end

    def list_start(attributes = [])
      _, itemType = attributes.detect { |a| a[0] == 'itemType' }
      itemType = qualify_type(itemType) if itemType
      SimpleTypeList.new(self, itemType)
    end

    def union_start(attributes = [])
      _, memberTypes = attributes.detect { |a| a[0] == 'memberTypes' }
      memberTypes = memberTypes.split(' ').collect { |type| qualify_type(type) } if memberTypes
      SimpleTypeUnion.new(self, memberTypes)
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
