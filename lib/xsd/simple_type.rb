module Xsd
  class SimpleType < NamedTag

    tag 'xs:simpleType'

    attr_reader :type

    def start_xs_restriction(attributes = [])
      _, base = attributes.detect { |a| a[0] == 'base' }
      SimpleTypeRestriction.new(self, base)
    end

    def start_xs_list(attributes = [])
      _, itemType = attributes.detect { |a| a[0] == 'itemType' }
      SimpleTypeList.new(self, itemType)
    end

    def start_xs_union(attributes = [])
      _, memberTypes = attributes.detect { |a| a[0] == 'memberTypes' }
      SimpleTypeUnion.new(self, memberTypes)
    end

    def when_end_xs_restriction(restriction)
      @type = restriction
    end

    def when_end_xs_list(list)
      @type = list
    end

    def when_end_xs_union(union)
      @type = union
    end

    def to_json_schema
      {'title' => name.to_title}.merge(type.to_json_schema)
    end
  end
end
