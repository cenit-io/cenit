module RailsAdmin
  module MongoffAttributeCommon

    def hash_schema
      if schema.is_a?(Hash)
        schema
      else
        {}
      end
    end

    def schema
      model.property_schema(name)
    end

    def visible?
      !hash_schema.has_key?('visible') || hash_schema['visible'].present?
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
      if (d = hash_schema['description']).is_a?(Array)
        d = d.join('<br>')
      end
      d
    end

    def group
      hash_schema['group']
    end

    def title
      hash_schema['title']
    end
  end
end