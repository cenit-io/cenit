module Cenit
  class ApplicationParameter
    include Setup::CenitScoped

    BASIC_TYPES =
      {
        integer: 'integer',
        number: 'number',
        boolean: 'boolean',
        string: 'string',
        object: 'object',
        json: { oneOf: [{ type: 'object' }, { type: 'array' }] }
      }.deep_stringify_keys

    def self.type_enum
      BASIC_TYPES.keys.to_a + Setup::Application.additional_parameter_types
    end

    build_in_data_type.referenced_by(:name).and(
      properties: {
        type: {
          enum: [
            'integer',
            'number',
            'boolean',
            'string',
            'object',
            'Namespace',
            'Flow',
            'Translator',
            'Event',
            'Algorithm',
            'Application',
            'Snippet',
            'Connection role',
            'Resource',
            'Operation',
            'Webhook',
            'Connection',
            'Data type',
            'Schema',
            'Custom validator',
            'Authorization',
            'Oauth provider',
            'Oauth client',
            'Generic client',
            'Oauth 2 scope'
          ]
        }
      }
    )

    field :name, type: String
    field :type, type: String
    field :many, type: Mongoid::Boolean
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
      if many
        referenced = sch.delete(:referenced)
        sch = { type: 'array', items: sch }
        sch[:referenced] = true if referenced
      end
      sch[:group] = group if group
      sch[:description] = description if description.present?
      sch.deep_stringify_keys
    end
  end
end
