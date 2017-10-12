require 'rails_admin/lib/mongoff_attribute_common'
require 'rails_admin/adapters/mongoid/property'

module RailsAdmin
  class MongoffProperty < RailsAdmin::Adapters::Mongoid::Property

    include RailsAdmin::MongoffAttributeCommon

    attr_reader :schema

    def initialize(property, model, schema = model.property_schema(property))
      @property = property.to_sym
      @model = model
      @schema = schema
    end

    def name
      @property
    end

    def pretty_name
      name.to_s.tr('_', ' ').capitalize
    end

    def type
      case hash_schema['type']
      when nil
        if name == :_id
          :sort_reverse_string
        else
          :json_value
        end
      when 'array', 'object'
        :json_value
      when 'number'
        :decimal
      when 'boolean'
        :boolean
        # when 'BSON::ObjectId', 'Moped::BSON::ObjectId'
        #   :bson_object_id
      when 'integer'
        :integer
      when 'string'
        case hash_schema['format']
        when 'date'
          :date
        when 'date-time', 'time'
          :datetime
        when 'cenit-oauth-scope'
          :cenit_oauth_scope
        when 'cenit-access-scope'
          :cenit_access_scope
        when 'auto-complete'
          :auto_complete
        else
          string_field_type
        end
      else
        :string
      end
    end

    def enum
      @enum ||=
        if (enum = hash_schema['enum']) && (names = hash_schema['enumNames'])
          hash = {}
          enum.each_with_index { |value, index| hash[names[index] || value] = value }
          hash
        else
          enum
        end
    end

    def enum_for_select
      @enum_for_select ||=
        if enum && (enum_options = hash_schema['enumOptions'].dup)
          enum.to_a.collect { |e| [e, enum_options.shift].compact.flatten }
        else
          enum
        end
    end

    def length
      (length_validation_lookup || 255) if type == :string
    end

    private

    # def object_field_type
    #   if [:belongs_to, :referenced_in, :embedded_in].
    #     include?(model.relations.values.detect { |r| r.foreign_key.try(:to_sym) == name }.try(:macro).try(:to_sym))
    #     :bson_object_id
    #   else
    #     :string
    #   end
    # end

    def string_field_type
      type =
        if ((length = length_validation_lookup) && length < 256) || STRING_TYPE_COLUMN_NAMES.include?(name)
          :string
        else
          :text
        end
      #Empty Test
      if !required? &&
        ((((min = hash_schema['minLength']) && (min > 0 || (min == 0 && hash_schema['exclusiveMaximum']))) ||
          ((pattern = hash_schema['pattern']) && !''.match(pattern))))

        type = "non_empty_#{type}"
      end
      type
    end

    def length_validation_lookup
      hash_schema['maxLength']
    end
  end
end
