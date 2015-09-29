module Setup
  class DataTypeGeneration < Setup::Task

    BuildInDataType.regist(self)

    Setup::Models.exclude_actions_for self, :new, :edit, :update, :delete_all

    def run(message)
      message = message.with_indifferent_access
      json_schemas = Setup::DataTypeGeneration.data_type_schemas(message[:source], {data_type_names: data_type_names = {}})
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
            data_type_schemas[name] =
              if data_type.validate_model
                new_data_types_attributes << data_type.attributes
                data_type.id
              else
                nil
              end
          end
          Setup::DataType.collection.insert(new_data_types_attributes)
        end
      end
      Setup::Schema.any_in(id: data_type_names.keys).each do |schema|
        schema[:data_type_id] = json_schemas[schema[:library_id]][data_type_names[schema.id]]
        schema.save
      end if data_type_names.present?
    end

    class << self
      def data_type_schemas(source, options = {})
        options[:schemas] = schemas =
          case source
          when nil # All schemas
            Setup::Schema.all
          when Array # bulk schema ids
            Setup::Schema.any_in(id: source)
          else
            [source]
          end
        schemas.each(&:bind_includes)
        json_schemas = Hash.new { |h, k| h[k] = {} }
        data_type_names = options[:data_type_names]
        schemas.each do |schema|
          json_schemas[schema[:library_id]].merge!(json_schms = schema.json_schemas)
          if data_type_names && name = schema.instance_variable_get(:@data_type_name)
            data_type_names[schema.id] = name
          end
        end
        json_schemas
      end
    end

  end
end
