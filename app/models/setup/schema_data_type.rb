require 'edi/formater'

module Setup
  class SchemaDataType < DataType

    BuildInDataType.regist(self).referenced_by(:name, :library).with(:title, :name, :slug,:_type, :schema, :events, :before_save_callbacks, :records_methods, :data_type_methods).including(:library)

    field :schema

    def read_attribute(name)
      value = super
      if name.to_s == 'schema' && value.is_a?(String)
        attributes['schema'] = value = JSON.parse(value) rescue value
      end
      value
    end

    def model_attributes
      ['schema']
    end

    def on_saving
      if validate_model && super
        attributes['schema'] = attributes['schema'].to_json unless attributes['schema'].is_a?(String)
        true
      else
        false
      end
    end

    def schema_changed?
      changed_attributes.has_key?('schema')
    end

    def validate_model
      if schema.blank?
        errors.add(:schema, "can't be blank")
      elsif schema_changed?
        begin
          json_schema, _ = validate_schema
          fail Exception, 'defines invalid property name: _type' if object_schema?(json_schema) &&json_schema['properties']['_type']
          self.schema = check_id_property(JSON.parse(json_schema.to_json))
          self.title = json_schema['title'] || self.name if title.blank?
        rescue Exception => ex
          #TODO Remove raise
          #raise ex
          errors.add(:schema, ex.message)
        end
        @collection_data_type = nil
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

    protected

    def do_load_model(report)
      parse_schema(report)
    end

    def validate_schema
      # check_type_name(self.name)
      self.schema = JSON.parse(schema) unless schema.is_a?(Hash)
      JSON::Validator.validate!(File.read(File.dirname(__FILE__) + '/schema.json'), schema.to_json)
      if schema['type'] == 'object'
        check_schema(schema, self.name, defined_types=[], embedded_refs={}, schema)
      end
      [schema, embedded_refs]
    end

    def check_schema(json, name, defined_types, embedded_refs, root_schema)
      if refs = json['$ref']
        refs = [refs] unless refs.is_a?(Array)
        refs.each { |ref| embedded_refs[ref] = check_embedded_ref(ref, root_schema) if ref.start_with?('#') }
      elsif json['type'].nil? || json['type'].eql?('object')
        defined_types << name
        check_definitions(json, name, defined_types, embedded_refs, root_schema)
        if properties = json['properties']
          raise Exception.new('properties specification is invalid') unless properties.is_a?(Hash)
          properties.each do |property_name, property_spec|
            unless property_name == '$ref'
              check_property_name(property_name)
              raise Exception.new("specification of property '#{property_name}' is not valid") unless property_spec.is_a?(Hash)
              if defined_types.include?(camelized_property_name = "#{name}::#{property_name.camelize}") && !(property_spec['$ref'] || 'object'.eql?(property_spec['type']))
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
      if required = json['required']
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
      if defs = json['definitions']
        raise Exception.new('definitions format is invalid') unless defs.is_a?(Hash)
        defs.each do |def_name, def_spec|
          raise Exception.new("type definition '#{def_name}' is not an object type") unless def_spec.is_a?(Hash) && (def_spec['type'].nil? || def_spec['type'].eql?('object'))
          check_definition_name(def_name)
          raise Exception.new("'#{parent.underscore}/#{def_name}' definition is declared as a reference (use the reference instead)") if def_spec['$ref']
          raise Exception.new("'#{parent.underscore}' already defines #{def_name}") if defined_types.include?(camelized_def_name = "#{parent}::#{def_name.camelize}")
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

    RJSON_MAP={'string' => 'String',
               'integer' => 'Integer',
               'number' => 'Float',
               'array' => 'Array',
               'boolean' => 'Boolean',
               'date' => 'Date',
               'time' => 'Time',
               'date-time' => 'DateTime'}

    MONGO_TYPES= %w{Array BigDecimal Boolean Date DateTime Float Hash Integer Range String Symbol Time}

    def find_constant(name)
      reflect_constant(name, :do_not_create)[0]
    end

    def reflect_constant(name, value = nil, parent = nil, base_class = Object)
      model_name = (parent ? "#{parent.to_s}::" : '') + name
      do_not_create = value == :do_not_create
      tokens = name.split('::')
      constant_name = tokens.pop

      base_class ||= Object
      raise Exception.new("illegal base class #{base_class} for build in constant #{constant_name}") if MONGO_TYPES.include?(constant_name) && base_class != Object

      parent ||= Object

      tokens.each do |token|
        if (parent.const_defined?(token, false) rescue false)
          parent = parent.const_get(token)
        else
          return [nil, false] if do_not_create
          new_m = Class.new
          parent.const_set(token, new_m)
          parent = new_m
        end
      end

      created = false
      if (parent.const_defined?(constant_name, false) rescue false)
        constant = parent.const_get(constant_name)
      else
        return [nil, false] if do_not_create
        constant = Class.new(base_class) unless value && constant = Mongoff::Model.for(data_type: self,
                                                                                       name: name,
                                                                                       parent: parent,
                                                                                       schema: parent ? value : nil,
                                                                                       cache: false,
                                                                                       modelable: false)
        parent.const_set(constant_name, constant)
        created = true
      end

      unless do_not_create
        if constant.is_a?(Class)
          puts "schema_name -> #{schema_name = (parent == Object ? self.name : parent.schema_name + '::' + constant_name)}"
          constant.class_eval("def self.schema_name
            '#{schema_name}'
          end")
          puts "Created model #{constant.schema_name} < #{base_class.to_s}"
          Setup::DataType.to_include_in_models.each do |module_to_include|
            unless constant.include?(module_to_include)
              puts "#{constant.to_s} including #{module_to_include.to_s}."
              constant.include(module_to_include)
            end
          end
          constant.class_eval("def self.data_type
            Setup::DataType.where(id: '#{self.id}').first
          end
          def orm_model
            self.class
          end")
        else
          puts "Created constant #{model_name}"
        end
      end
      [constant, created]
    end

    def parse_schema(report, model_name = data_type_name, schema = nil, root = nil, parent = nil, embedded = nil, schema_path = '')

      schema, embedded_refs = validate_schema unless schema

      schema = merge_schema!(schema, expand_extends: false)

      base_ref = nil
      base_model = nil
      if (base_schema = schema.delete('extends')) && base_schema.is_a?(String)
        base_ref = base_schema
        if base_model = find_or_load_model(report, base_schema)
          base_schema = base_model.data_type.merged_schema
        else
          raise Exception.new("requires base model #{base_schema} to be already loaded")
        end
      end

      check_id_property(schema)

      if base_schema
        if base_model.is_a?(Class)
          schema = merge_schema!(schema, only_overriders: true, extends: base_ref)
        else
          if schema['type'] == 'object' && base_schema['type'] != 'object'
            schema['properties'] ||= {}
            value_schema = schema['properties']['value'] || {}
            value_schema = base_schema.deep_merge(value_schema)
            schema['properties']['value'] = value_schema.merge('title' => 'Value', 'xml' => {'content' => true})
            (schema['xml'] ||= {})['content_property'] = 'value'
          else
            schema = base_schema.deep_merge(schema) { |key, val1, val2| Cenit::Utility.array_hash_merge(val1, val2) }
          end
        end
      end

      klass, created = reflect_constant(model_name, (object_schema?(schema) || base_model.is_a?(Class)) ? nil : schema, parent, base_model.is_a?(Class) ? base_model : nil)
      base_model.affects_to(klass) if base_model

      return klass unless created && klass.is_a?(Class)

      root ||= klass
      unless mongoff_models = klass.instance_variable_get(:@mongoff_models)
        klass.instance_variable_set(:@mongoff_models, mongoff_models = {})
      end

      embedded_refs.each do |path, model_name|
        puts "Loading embedded ref #{path} -> #{model_name}"
        name, ref_schema = get_embedded_schema(path, schema)
        raise '!!!' if model_name != name
        parse_schema(report, model_name, ref_schema, root, klass, :embedded, path)
      end if embedded_refs

      nested = []
      enums = {}
      validations = []
      required = schema['required'] || []

      model_name = klass.model_access_name

      reflect(klass, "def self.title
        '#{schema['title']}'
      end
      def self.schema_path
        '#{schema_path}'
      end")

      puts "Parsing #{klass.schema_name}"

      if definitions = schema['definitions']
        definitions.each do |key, def_desc|
          def_name = key.camelize
          puts 'Defining ' + def_name
          parse_schema(report, def_name, def_desc, root ? root : klass, klass, :embedded, "#{schema_path}/definitions/#{key}")
        end
      end

      check_id_property(schema)

      if properties = schema['properties']
        raise Exception.new('properties definition is invalid') unless properties.is_a?(Hash)
        properties = merge_schema(properties)
        properties.each do |property_name, property_desc|
          raise Exception.new("property '#{property_name}' definition is invalid") unless property_desc.is_a?(Hash)
          check_property_name(property_name)

          v = nil
          still_trying = true
          referenced = property_desc['referenced']

          property_desc = merge_schema(property_desc, expand_extends: false) if property_desc['type'] || property_desc['properties']

          while still_trying && ref = property_desc['$ref'] # property type contains a reference
            still_trying = false
            if ref.is_a?(String)
              if ref.start_with?('#') # an embedded reference
                raise Exception.new("referencing embedded reference #{ref}") if referenced
                property_type = check_embedded_ref(ref, schema, root.model_access_name)
                if type_model = find_constant(property_type)
                  if type_model.is_a?(Class)
                    v = "embeds_one :#{property_name}, class_name: '#{type_model.to_s}', inverse_of: :#{relation_name(model_name, property_name)}"
                    reflect(type_model, "embedded_in :#{relation_name(model_name, property_name)}, class_name: '#{model_name}', inverse_of: :#{property_name}")
                    nested << property_name
                  else
                    v = "field :#{property_name}"
                    validations << "validates_schema_of :#{property_name}, model: #{type_model}"
                    mongoff_models[property_name] = type_model
                  end
                else
                  raise Exception.new("refers to an invalid JSON reference '#{ref}'")
                end
              else # an external reference
                if MONGO_TYPES.include?(ref)
                  v = "field :#{property_name}, type: #{ref}"
                else
                  if type_model = (find_or_load_model(report, ref) || find_constant(ref))
                    unless type_model.is_a?(Class)
                      #is a Mongoff model
                      property_desc.delete('$ref')
                      property_desc = property_desc.merge(type_model.data_type.schema)
                      type_model.affects_to(klass)
                      still_trying = true
                    else
                      if referenced
                        v = "belongs_to :#{property_name}, class_name: '#{type_model.to_s}', inverse_of: nil"
                        type_model.affects_to(klass)
                      else
                        v = "embeds_one :#{property_name}, class_name: '#{type_model.to_s}', inverse_of: :#{relation_name(model_name, property_name)}"
                        reflect(type_model, "embedded_in :#{relation_name(model_name, property_name)}, class_name: '#{model_name}', inverse_of: :#{property_name}")
                        #type_model.affects_to(klass)
                        nested << property_name
                      end
                    end
                  else
                    raise Exception.new("contains an unresolved reference: '#{ref}'")
                  end
                end
              end
            else
              property_desc = merge_schema(property_desc, expand_extends: false)
            end
          end

          v = process_non_ref(report, property_name, property_desc, klass, root, nested, enums, validations, required) if still_trying

          reflect(klass, v) if v
        end
      end

      required.each do |p|
        reflect(klass, "validates_presence_of :#{p}") if klass.fields.keys.include?(p) || klass.relations.keys.include?(p)
      end

      validations.each { |v| reflect(klass, v) }

      schema['assertions'].each { |assertion| reflect(klass, "validates assertion: #{assertion}") } if schema['assertions']

      enums.each do |property_name, enum|
        reflect(klass, %{
          def #{property_name}_enum
            #{enum.to_s}
          end
          })
      end

      if (key = (schema['name'] || schema['title'])) && !klass.instance_methods.detect { |m| m == :name }
        reflect(klass, "def name
            #{"\"#{key}\""}
          end")
      end

      %w{title description}.each do |key|
        if value = schema[key]
          reflect(klass, %{
            def self.#{key}
              "#{value}"
            end
            }) unless klass.respond_to? key
        end
      end

      nested.each { |n| reflect(klass, "accepts_nested_attributes_for :#{n}, allow_destroy: true") }

      puts "Parsing #{klass.schema_name} done!"
      klass
    end

    def find_or_load_model(report, ref)
      if (data_type = find_data_type(ref)) && !data_type.to_be_destroyed
        puts "Reference #{ref} found!"
        if data_type.loaded?
          data_type.model
        else
          merge_report(r = data_type.load_models, report)
          report.delete(:model)
        end
      else
        puts "Reference #{ref} NOT FOUND!"
        nil
      end
    end

    def process_non_ref(report, property_name, property_desc, klass, root, nested=[], enums={}, validations=[], required=[])

      unless mongoff_models = klass.instance_variable_get(:@mongoff_models)
        klass.instance_variable_set(:@mongoff_models, mongoff_models = {})
      end
      property_desc = merge_schema(property_desc, expand_extends: false)
      model_name = klass.model_access_name
      still_trying = true

      while still_trying
        still_trying = false
        property_type = property_desc['type']
        if property_type == 'string' && %w{date time date-time}.include?(property_desc['format'])
          property_type = property_desc.delete('format')
        end
        property_type_backup = property_type = RJSON_MAP[property_type] if RJSON_MAP[property_type]
        v =nil
        type_model = nil
        type_model_created = false
        if property_type.eql?('Array') && (items_desc = property_desc['items']).is_a?(Hash)
          items_desc = merge_schema(items_desc, expand_extends: false) if items_desc['type'] || items_desc['properties']
          r = nil
          ir = ''
          if (ref = items_desc['$ref']).is_a?(String) && (!ref.start_with?('#') && property_desc['referenced'])
            if (type_model = (find_or_load_model(report, property_type = ref) || find_constant(ref))).is_a?(Class)
              property_type = type_model.model_access_name
              r = :has_and_belongs_to_many
              ir = ', inverse_of: nil'
              type_model.affects_to(klass)
            elsif type_model.nil?
              raise Exception.new("contains an unresolved reference: '#{ref}'")
            end
          else
            r = :embeds_many
            if ref.is_a?(String)
              raise Exception.new("referencing embedded reference #{ref}") if property_desc['referenced']
              property_type = ref.start_with?('#') ? check_embedded_ref(ref, nil, root.to_s).singularize : ref
              type_model = find_or_load_model(report, property_type) || find_constant(property_type)
              property_type = type_model && type_model.model_access_name
            else
              property_type = (type_model = parse_schema(report, property_name.camelize.singularize, property_desc['items'], root, klass, :embedded, klass.schema_path + "/properties/#{property_name}/items")).model_access_name
              type_model_created = true
            end
            if type_model.is_a?(Class)
              ir = ", inverse_of: :#{relation_name(model_name, property_name)}"
              reflect(type_model, "embedded_in :#{relation_name(model_name, property_name)}, class_name: '#{model_name}', inverse_of: :#{property_name}")
              nested << property_name if r
            else
              raise Exception.new("contains an unresolved reference: '#{ref}'") if type_model.nil?
              r = nil
            end
          end
          if r
            v = "#{r} :#{property_name}, class_name: '#{property_type.to_s}'" + ir

            if property_desc['maxItems'] && property_desc['maxItems'] == property_desc['minItems']
              validations << "validates_association_length_of :#{property_name}, is: #{property_desc['maxItems'].to_s}"
            elsif property_desc['maxItems'] || property_desc['minItems']
              validations << "validates_association_length_of :#{property_name}#{property_desc['minItems'] ? ', minimum: ' + property_desc['minItems'].to_s : ''}#{property_desc['maxItems'] ? ', maximum: ' + property_desc['maxItems'].to_s : ''}"
            end
          end
        end
        unless v
          property_type = property_type_backup
          if property_type.nil? || property_type.eql?('object') || property_type.eql?('Array')
            if type_model && type_model_created
              puts "Destroying created model #{type_model}"
              klass.send(:remove_const, type_model.name)
            end
            property_type = (type_model = parse_schema(report, property_name.camelize, property_desc, root, klass, :embedded, klass.schema_path + "/properties/#{property_name}")).model_access_name
            if type_model.is_a?(Class)
              v = "embeds_one :#{property_name}, class_name: '#{type_model.to_s}', inverse_of: :#{relation_name(model_name, property_name)}"
              reflect(type_model, "embedded_in :#{relation_name(model_name, property_name)}, class_name: '#{model_name}', inverse_of: :#{property_name}")
              nested << property_name
            else # is a Mongoff Model
              v = "field :#{property_name}"
              validations << "validates_schema_of :#{property_name}, model: #{property_type}"
              mongoff_models[property_name] = type_model
            end
          end
          unless v
            mongoff_models[property_name] = Mongoff::Model.for(data_type: self,
                                                               name: property_name.camelize,
                                                               parent: klass,
                                                               schema: property_desc,
                                                               cache: false,
                                                               modelable: false)
            if property_type
              v = "field :#{property_name}, type: #{property_type}"
              v += ", default: \'#{property_desc['default']}\'" if property_desc['default']
            end
            if enum = property_desc['enum']
              enums[property_name] = enum
              validations << "validates_inclusion_in_presence_of :#{property_name}, in: -> (record) { record.#{property_name}_enum }, message: 'is not a valid value'"
            elsif property_desc['pattern']
              validations << "validates_format_in_presence_of :#{property_name}, :with => /\\A#{property_desc['pattern']}\\Z/i"
            end
            if property_desc['minLength'] || property_desc['maxLength']
              validations << "validates_length_in_presence_of :#{property_name}#{property_desc['minLength'] ? ', minimum: ' + property_desc['minLength'].to_s : ''}#{property_desc['maxLength'] ? ', maximum: ' + property_desc['maxLength'].to_s : ''}"
            end
            constraints = []
            if property_desc['minimum']
              constraints << (property_desc['exclusiveMinimum'] ? 'greater_than: ' : 'greater_than_or_equal_to: ') + property_desc['minimum'].to_s
            end
            if property_desc['maximum']
              constraints << (property_desc['exclusiveMaximum'] ? 'less_than: ' : 'less_than_or_equal_to: ') + property_desc['maximum'].to_s
            end
            if constraints.length > 0
              validations << "validates_numericality_in_presence_of :#{property_name}, {#{constraints[0] + (constraints[1] ? ', ' + constraints[1] : '')}}"
            end
          end
          if property_desc['unique']
            validations << "validates_uniqueness_in_presence_of :#{property_name}"
          end
        end
      end
      v
    end

    def relation_name(model, inverse_relation)
      "#{inverse_relation}_on_#{model.to_s.underscore.split('/').join('_')}"
    end

    def reflect(c, code)
      puts "#{c.schema_name rescue c.to_s}  #{code ? code : 'WARNING REFLECTING NIL CODE'}"
      c.class_eval(code) if code
    end

    def find_embedded_ref(root, ref)
      begin
        ref.split('/').each do |name|
          unless name.length == 0 || name.eql?('#') || name.eql?('definitions')
            root = root.const_get(name.camelize)
          end
        end
        return root
      rescue
        return nil
      end
    end
  end
end
