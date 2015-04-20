module Setup
  class Validator < ReqRejValidator
    include CenitScoped

    #Setup::Models.exclude_actions_for self, :edit, :update, :delete, :bulk_delete, :delete_all

    BuildInDataType.regist(self).referenced_by(:name, :library)

    belongs_to :library, class_name: Setup::Library.to_s, inverse_of: :validators

    field :name, type: String
    field :style, type: String

    belongs_to :schema, class_name: Setup::Schema.to_s, inverse_of: nil

    field :validation, type: String

    validates_presence_of :library, :name, :style
    validates_uniqueness_of :name

    before_save :validates_configuration

    def validates_configuration
      if schema_style?
        unless requires(:schema)
          errors.add(:schema, 'library mismatch') unless schema.library == library
          errors.add(:schema, 'style and schema type mismatch') unless schema.schema_type == schema_type
        end
      else
        requires(:validation)
      end
      errors.blank?
    end

    def ready_to_save?
      style.present?
    end

    def can_be_restarted?
      library.present?
    end

    def style_enum
      ['JSON Schema', 'XML Schema']#, 'ruby']
    end

    def schema_style?
      style.end_with?('Schema')
    end

    def schema_type
      schema_style? ? style.downcase.gsub(' ', '_').to_sym : nil
    end

    def script_style?
      !schema_style?
    end

    def validate_data!(data)
      case schema_type
      when :json_schema
        JSON::Validator.validate!(@schema ||= schema.data_types.first.merged_schema(recursive: true), JSON.parse(data))
      when :xml_schema
        if (errors = Nokogiri::XML::Schema(schema.cenit_ref_schema).validate(Nokogiri::XML(data))).present?
          raise Exception.new(errors[0])
        end
      when :ruby
      end
    end
  end
end
