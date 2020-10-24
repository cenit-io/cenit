module Cenit
  class ApplicationParameter
    include Setup::CenitScoped

    build_in_data_type.referenced_by(:name)

    field :name, type: String
    field :type, type: String
    field :many, type: Boolean
    field :group, type: String
    field :description, type: String

    validates_uniqueness_of :name
    validates_format_of :name, with: /\A[a-z]([a-z]|_|\d)*\Z/

    validate do
      self.group = nil if group.blank?
      self.description = nil if description.blank?
      errors.add(:name, 'is not allowed') if Cenit::AppConfig::BANED_PARAMETER_NAMES.include?(name)
      errors.blank?
    end

    def group_s
      group.to_s
    end

    BASIC_TYPES =
      {
        integer: 'integer',
        number: 'number',
        boolean: 'boolean',
        string: 'string',
        object: 'object',
        json: { oneOf: [{ type: 'object' }, { type: 'array' }] }
      }.deep_stringify_keys

    def type_enum
      BASIC_TYPES.keys.to_a + Setup::Application.additional_parameter_types
    end

    def group_enum
      (application && application.application_parameters.collect(&:group).uniq.select(&:present?)) || []
    end

    def schema
      sch =
        if type.blank?
          {}
        elsif (json_type = BASIC_TYPES[type])
          json_type.is_a?(Hash) ? json_type : { type: json_type }
        else
          Setup::Application.parameter_type_schema(type)
        end
      sch = (many ? { type: 'array', items: sch } : sch)
      sch[:referenced] = true unless BASIC_TYPES.has_key?(type) || type.blank?
      sch[:group] = group if group
      sch[:description] = description if description.present?
      sch.deep_stringify_keys
    end
  end
end
