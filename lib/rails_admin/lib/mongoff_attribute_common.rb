module RailsAdmin
  module MongoffAttributeCommon

    def visible?
      !schema.has_key?('visible') || schema['visible'].present?
    end

    def filterable?
      true
    end

    def required?
      model.requires?(name)
    end

    def description
      schema['description']
    end

    def group
      schema['group']
    end

    def title
      schema['title']
    end
  end
end