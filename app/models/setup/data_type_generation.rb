module Setup
  class DataTypeGeneration < Setup::Task

    build_in_data_type

    def run(message)
      message = message.with_indifferent_access
      json_schemas = Setup::DataTypeGeneration.data_type_schemas(message[:source], { data_type_names: data_type_names = {} })
      json_schemas.each do |ns, data_type_schemas|
        existing_data_types = Setup::DataType.any_in(namespace: ns, name: data_type_schemas.keys)
        if existing_data_types.present?
          if message[:override_data_types].to_b
            existing_data_types.each do |data_type|
              data_type_schemas[data_type.name] =
                if data_type.update(schema: data_type_schemas.delete(data_type.name))
                  data_type.id
                else
                  # TODO: Handling data type generation errors
                  nil
                end
            end
          else
            fail "Can not override existing data types without override option: #{existing_data_types.collect(&:name).to_sentence}"
          end
        end
        data_type_schemas.each do |name, schema|
          next unless schema.is_a?(Hash)
          data_type = Setup::JsonDataType.create(namespace: ns, name: name, schema: schema)
          data_type_schemas[name] =
            if data_type.errors.present?
              # TODO:  Handling data type generation errors
              nil
            else
              data_type.id
            end
        end
      end
      if data_type_names.present?
        Setup::Schema.any_in(id: data_type_names.keys).each do |schema|
          schema.update(schema_data_type_id: json_schemas[schema[:namespace]][data_type_names[schema.id]])
        end
      end
    end

    class << self
      def data_type_schemas(source, options = {})
        options[:schemas] = schemas =
          case source
          when nil # All schemas
            Setup::Schema.all
          when Hash # Query selector
            Setup::Schema.where(source)
          when Array # bulk schema ids
            Setup::Schema.any_in(id: source)
          else
            [source]
          end
        if (c = schemas.count) > ::Cenit.max_handling_schemas
          fail "Too many schemas to handle: #{c} (> #{::Cenit.max_handling_schemas})"
        end
        schemas = schemas.to_a
        ns_schemas = Hash.new { |h, k| h[k] = [] }
        nss = {}
        schemas.each do |schema|
          ns = schema.namespace_ns.name
          if nss.key?(ns)
            schema.namespace_ns = nss[ns]
          else
            nss[ns] = schema.namespace_ns
          end
          ns_schemas[ns] << schema
        end
        nss.each do |ns, namespace_ns|
          namespace_ns.set_schemas_scope(ns_schemas[ns])
        end
        schemas.each(&:bind_includes)
        json_schemas = Hash.new { |h, k| h[k] = {} }
        data_type_names = options[:data_type_names]
        schemas.each do |schema|
          json_schemas[schema[:namespace]].merge!(schema.json_schemas)
          if data_type_names && (name = schema.instance_variable_get(:@data_type_name))
            data_type_names[schema.id] = name
          end
        end
        json_schemas
      end
    end

  end
end
