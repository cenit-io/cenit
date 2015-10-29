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
  end
end