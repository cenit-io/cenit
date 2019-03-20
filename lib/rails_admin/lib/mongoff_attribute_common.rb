module RailsAdmin
  module MongoffAttributeCommon
    def hash_schema
      if schema.is_a?(Hash)
        schema
      else
        @_empty_hash ||= {}
      end
    end

    def schema
      model.property_schema(name)
    end

    def visible?
      if name == :_id
        (hash_schema.key?('visible') && hash_schema['visible'].to_s.to_b) ||
          hash_schema.key?('type')
      else
        !hash_schema.key?('visible') || hash_schema['visible'].to_s.to_b
      end
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

    def read_only?
      name == :_id || hash_schema['readOnly'].to_s.to_b
    end
  end
end