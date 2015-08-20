module Setup
  class Library
    include CenitScoped
    include Slug

    Setup::Models.exclude_actions_for self, :delete, :bulk_delete, :delete_all

    BuildInDataType.regist(self).embedding(:schemas, :file_data_types).referenced_by(:slug)

    field :name, type: String

    has_many :schemas, class_name: Setup::Schema.to_s, inverse_of: :library, dependent: :destroy
    has_many :file_data_types, class_name: Setup::FileDataType.to_s, inverse_of: :library, dependent: :destroy

    validates_presence_of :name
    validates_uniqueness_of :name

    after_initialize { @schemas_scope = {} }
    before_save :validates_name_uniqueness

    def validates_name_uniqueness
      hash = Hash.new { |h, k| h[k] = 0 }
      schemas.each { |schema| hash[schema.uri] += 1 }
      if (keys = hash.reject { |_, count| count == 1 }.keys).present?
        errors.add(:schemas, "Multiple schemas with the same URI: #{keys.to_sentence}")
      end
      if errors.blank?
        hash = Hash.new { |h, k| h[k] = 0 }
        schemas.each { |schema| schema.data_types.each { |data_type| hash[data_type.name] += 1 } }
        file_data_types.each { |data_type| hash[data_type.name] += 1 }
        if (keys = hash.reject { |_, count| count == 1 }.keys).present?
          errors.add(:schemas, "Multiple data types with the same name: #{keys.to_sentence}")
        end
      end
      errors.blank?
    end

    def find_data_type_by_name(name)
      if data_type = Setup::Model.where(library: self, name: name).first
        data_type
      else
        if (schema = Setup::Schema.where(library: self, uri: name).first) && schema.data_types.count == 1
          schema.data_types.first
        else
          nil
        end
      end
    end

    def set_schemas_scope(schemas)
      @schemas_scope = {}
      schemas.each { |schema| @schemas_scope[schema.uri] = schema }
    end

    def schema_for(base_uri, relative_uri)
      uri = Cenit::Utility.abs_uri(base_uri, relative_uri)
      if schema = @schemas_scope[uri]
        schema
      else
        schemas.where(uri: uri).first
      end
    end
  end
end
