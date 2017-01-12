module RailsAdmin
  module MongoffAttributeCommon

    def schema
      model.property_schema(name)
    end

    def visible?
      !schema.has_key?('visible') || schema['visible'].present?
    end

    def queryable?
      visible? #TODO Expands criteria to other fields when configuring index properties
    end

    def filterable?
      true
    end

    def required?
      model.requires?(name)
    end

    def description
      if (d = schema['description']).is_a?(Array)
        d = d.join('<br>')
      end
      d
    end

    def group
      schema['group']
    end

    def title
      schema['title']
    end
  end
end