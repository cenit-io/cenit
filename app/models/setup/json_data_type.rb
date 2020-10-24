module Setup
  class JsonDataType < DataType
    include Setup::SnippetCode

    validates_presence_of :namespace

    legacy_code_attribute :schema

    trace_include :schema

    build_in_data_type.referenced_by(:namespace, :name).with(
      :namespace,
      :name,
      :title,
      :_type,
      :snippet,
      :discard_additional_properties,
      :before_save_callbacks,
      :after_save_callbacks,
      :records_methods,
      :data_type_methods
    )
    build_in_data_type.and(
      properties: {
        schema: {
          edi: {
            discard: true
          }
        }
      }
    )

    allow :new, :import, :pull_import, :bulk_cross, :simple_cross, :bulk_expand, :simple_expand, :copy, :switch_navigation, :config

    shared_deny :simple_delete_data_type, :bulk_delete_data_type, :simple_expand, :bulk_expand

    DEFAULT_SCHEMA = {
      type: 'object',
      properties: {
        name: {
          type: 'string'
        }
      }
    }.deep_stringify_keys

    field :discard_additional_properties, type: Boolean, default: true

    after_initialize do
      self.schema = DEFAULT_SCHEMA if new_record? && @schema.nil?
    end

    def validates_configuration
      super && validate_model && check_indices &&
        remove_attribute(:schema)
    end

    def additional_properties?
      !discard_additional_properties
    end

    def code=(code)
      @schema = nil
      super
    end

    def set_relation(name, relation)
      r = super
      if name == :snippet
        @schema = nil
      end
      r
    end

    def schema_code
      schema!
    rescue
      code
    end

    def schema_code=(sch)
      self.schema = sch
    end

    def schema!
      @schema ||= JSON.parse(code)
    end

    def schema
      schema!
    rescue
      { ERROR: 'Invalid JSON syntax', schema: code }
    end

    def schema=(sch)
      old_schema = schema
      sch = JSON.parse(sch.to_s) unless sch.is_a?(Hash)
      self.code = JSON.pretty_generate(sch)
      @schema = sch
    rescue
      @schema = nil
      self.code = sch
    ensure
      unless Cenit::Utility.eql_content?(old_schema, @schema)
        changed_attributes['schema'] = old_schema
      end
    end

    def code_extension
      '.json'
    end

    def check_indices
      build_indices if schema_changed?
      errors.blank?
    end

    def unique_properties
      records_model.unique_properties
    end

    def build_indices
      unique_properties = self.unique_properties
      indexed_properties = []
      begin
        records_model.collection.indexes.each do |index|
          indexed_property = index['key'].keys.first
          if unique_properties.detect { |p| p == indexed_property }
            indexed_properties << indexed_property
          else
            begin
              records_model.collection.indexes.drop_one(index['name'])
            rescue Exception => ex
              errors.add(:schema, "with error dropping index #{indexed_property}: #{ex.message}")
            end
          end
        end
      rescue
        # Mongo driver raises an exception if the collection does not exists, nothing to worry about
      end
      unique_properties.reject { |p| indexed_properties.include?(p) }.each do |p|
        next if p == '_id'
        begin
          records_model.collection.indexes.create_one({ p => 1 }, unique: true)
        rescue Exception => ex
          errors.add(:schema, "with error when creating index for unique property '#{p}': #{ex.message}")
        end
      end
      errors.blank?
    end

    def schema_changed?
      changed_attributes.key?('schema')
    end

    def validate_model
      if schema_code.is_a?(Hash)
        if schema_changed?
          begin
            json_schema, _ = validate_schema
            fail Exception, 'defines invalid property name: _type' if object_schema?(json_schema) && json_schema['properties'].key?('_type')
            self.schema = check_properties(JSON.parse(json_schema.to_json), skip_id_refactoring: true)
          rescue Exception => ex
            errors.add(:schema, ex.message)
          end
          @collection_data_type = nil
        end
        json_schema ||= schema
        if title.blank?
          self.title = json_schema['title'] || self.name
        end
      else
        errors.add(:schema_code, 'is not a valid JSON value')
      end
      errors.blank?
    end

    def subtype?
      collection_data_type != self
    end

    def collection_data_type
      @collection_data_type ||=
        ((base = schema['extends']) && base.is_a?(String) && (base = find_data_type(base)) && base.collection_data_type) || self
    end

    def data_type_collection_name
      Account.tenant_collection_name(collection_data_type.data_type_name)
    end

    def each_ref(params = {}, &block)
      params[:visited] ||= Set.new
      params[:not_found] ||= Set.new
      for_each_ref(params[:visited], params, &block)
    end

    protected

    def for_each_ref(visited = Set.new, params = {}, &block)
      schema = params[:schema] || self.schema
      not_found = params[:not_found]
      refs = []
      if (ref = schema['$ref'])
        refs << ref
      end
      if (ref = schema['extends']).is_a?(String)
        refs << ref
      end
      refs.flatten.each do |ref|
        if (data_type = find_data_type(ref))
          if visited.exclude?(data_type)
            visited << data_type
            block.call(data_type)
            data_type.for_each_ref(visited, not_found: not_found, &block) if data_type.is_a?(Setup::JsonDataType)
          end
        else
          not_found << ref
        end
      end
      schema.each do |key, value|
        next unless value.is_a?(Hash) && %w(extends $ref).exclude?(key)
        for_each_ref(visited, schema: value, not_found: not_found, &block)
      end
    end

    def validate_schema
      # check_type_name(self.name)
      self.schema = JSON.parse(schema) unless schema.is_a?(Hash)
      ::Mongoff::Validator.validate(schema)
      embedded_refs = {}
      if schema['type'] == 'object'
        check_schema(schema, self.name, defined_types = [], embedded_refs, schema)
      end
      [schema, embedded_refs]
    end

    def check_schema(json, name, defined_types, embedded_refs, root_schema)
      if (refs = json['$ref'])
        refs = [refs] unless refs.is_a?(Array)
        refs.each { |ref| embedded_refs[ref] = check_embedded_ref(ref, root_schema) if ref.is_a?(String) && ref.start_with?('#') }
      elsif json['type'].nil? || json['type'].eql?('object')
        defined_types << name
        check_definitions(json, name, defined_types, embedded_refs, root_schema)
        if (properties = json['properties'])
          raise Exception.new('properties specification is invalid') unless properties.is_a?(Hash)
          properties.each do |property_name, property_spec|
            unless property_name == '$ref'
              check_property_name(property_name)
              raise Exception.new("specification of property '#{property_name}' is not valid") unless property_spec.is_a?(Hash)
              camelized_property_name = "#{name}::#{property_name.camelize}"
              if defined_types.include?(camelized_property_name) && !(property_spec['$ref'] || 'object'.eql?(property_spec['type']))
                raise Exception.new("'#{name.underscore}' already defines #{property_name} (use #/[definitions|properties]/#{property_name} instead)")
              end
              check_schema(property_spec, camelized_property_name, defined_types, embedded_refs, root_schema)
            end
          end
        end
        check_requires(json)
      end
    end

    def check_requires(json)
      properties = json['properties']
      if (required = json['required'])
        if required.is_a?(Array)
          required.each do |property|
            if property.is_a?(String)
              raise Exception.new("requires undefined property '#{property.to_s}'") unless properties && properties[property]
            else
              raise Exception.new("required item \'#{property.to_s}\' is not a property name (string)")
            end
          end
        else
          raise Exception.new('required clause is not an array')
        end
      end
    end

    def check_definitions(json, parent, defined_types, embedded_refs, root_schema)
      if (defs = json['definitions'])
        raise Exception.new('definitions format is invalid') unless defs.is_a?(Hash)
        defs.each do |def_name, def_spec|
          raise Exception.new("type definition '#{def_name}' is not an object type") unless def_spec.is_a?(Hash) && (def_spec['type'].nil? || def_spec['type'].eql?('object'))
          check_definition_name(def_name)
          raise Exception.new("'#{parent.underscore}/#{def_name}' definition is declared as a reference (use the reference instead)") if def_spec['$ref']
          camelized_def_name = "#{parent}::#{def_name.camelize}"
          raise Exception.new("'#{parent.underscore}' already defines #{def_name}") if defined_types.include?(camelized_def_name)
          check_schema(def_spec, camelized_def_name, defined_types, embedded_refs, root_schema)
        end
      end
    end

    def check_definition_name(def_name)
      #raise Exception.new("definition name '#{def_name}' is not valid") unless def_name =~ /\A([A-Z]|[a-z])+(_|([0-9]|[a-z]|[A-Z])+)*\Z/
      raise Exception.new("definition name '#{def_name}' is not valid") unless def_name =~ /\A[a-z]+(_|([0-9]|[a-z])+)*\Z/
    end

    def check_property_name(property_name)
      #TODO Check for a valid ruby method name
      #raise Exception.new("property name '#{property_name}' is invalid") unless property_name =~ /\A[a-z]+(_|([0-9]|[a-z])+)*\Z/
    end

  end
end
