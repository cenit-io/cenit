module Setup
  class DataTypeGeneration < Setup::Task

    BuildInDataType.regist(self)

    Setup::Models.exclude_actions_for self, :new, :edit, :update, :delete_all

    def run(message)
      message = message.with_indifferent_access
      json_schemas = Setup::DataTypeGeneration.data_type_schemas(message[:source], message)
      json_schemas.each do |library_id, data_type_schemas|
        existing_data_types = Setup::DataType.any_in(library_id: library_id, name: data_type_schemas.keys)
        if existing_data_types.present?
          if message[:override_data_types].to_b
            Setup::DataType.shutdown(existing_data_types, deactivate: true)
            existing_data_types.each do |data_type|
              data_type.schema = data_type_schemas.delete(data_type.name)
              data_type.save
            end
          else
            fail "Can not override existing data types without override option: #{existing_data_types.collect(&:name).to_sentence}"
          end
        end
        if data_type_schemas.present?
          new_data_types_attributes = []
          data_type_schemas.each do |name, schema|
            data_type = Setup::SchemaDataType.new(name: name, schema: schema, library_id: library_id)
            new_data_types_attributes << data_type.attributes if data_type.validate_model
          end
          Setup::DataType.collection.insert(new_data_types_attributes)
        end
      end
    end

    def self.data_type_schemas(source, options = {})
      schemas =
        case source
        when nil # All schemas
          Setup::Schema.all
        when Array # bulk schema ids
          Setup::Schema.any_in(id: source)
        else
          [source]
        end
      json_schemas = Hash.new { |h, k| h[k] = {} }
      schemas.each { |schema| json_schemas[schema.library.id].merge!(schema.json_schemas) }
      json_schemas
    end

  end
end
