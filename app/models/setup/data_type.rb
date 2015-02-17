require 'edi/formater'

module Setup
  class DataType < BaseDataType
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Trackable

    BuildInDataType.regist(self).referenced_by(:name)

    def self.to_include_in_models
      @to_include_in_models ||= [Mongoid::Document, Mongoid::Timestamps, EventLookup, AccountScoped, DynamicValidators, Edi::Formatter, Edi::Filler] #, MakeSlug, RailsAdminDynamicCharts::Datetime
    end

    def self.to_include_in_model_classes
      @to_include_in_model_classes ||= [AffectRelation]
    end

    belongs_to :uri, class_name: Setup::Schema.to_s

    field :title, type: String
    field :name, type: String
    field :schema, type: String
    field :sample_data, type: String

    # has_many :events, class_name: Setup::Event.name, dependent: :destroy, inverse_of: :data_type
    #TODO Check dependent behavior with flows
    #has_many :flows, class_name: Setup::Flow.name, dependent: :destroy, inverse_of: :data_type

    validates_presence_of :name, :schema

    after_initialize :verify_schema_ok
    before_save :validate_model
    after_save :verify_schema_ok
    before_destroy :delete_all

    field :is_object, type: Boolean
    field :schema_ok, type: Boolean
    field :previous_schema, type: String
    field :activated, type: Boolean, default: false
    field :show_navigation_link, type: Boolean
    field :to_be_destroyed, type: Boolean

    scope :activated, -> { where(activated: true) }

    def new_from_edi(data, options={})
      Edi::Parser.parse_edi(self, data, options)
    end

    def new_from_json(data, options={})
      Edi::Parser.parse_json(self, data, options)
    end

    def new_from_xml(data, options={})
      Edi::Parser.parse_xml(self, data, options)
    end

    def sample_to_s
      '{"' + name.underscore + '": ' + sample_data + '}'
    end

    def sample_object
      model.new(JSON.parse(sample_data))
    end

    def sample_to_hash
      JSON.parse(sample_to_s)
    end

    def shutdown(options={})
      DataType.shutdown(self, options)
    end

    def model
      data_type_name.constantize rescue nil
    end

    def loaded?
      model ? true : false
    end

    def data_type_name
      "Dt#{self.id.to_s}"
    end

    def count
      if is_object?
        #TODO Count records when not loaded
        (m = model) ? m.count : 123
      else
        0
      end
    end

    def delete_all
      if  m = model
        m.delete_all unless m.is_a?(Hash)
      else
        #TODO Delete records
      end
    end

    def to_be_destroyed?
      to_be_destroyed
    end

    def load_model(options={})
      load_models(options)[:model]
    end

    def load_models(options={reload: false, reset_config: true})
      report = {loaded: Set.new, errors: {}}
      begin
        if (do_shutdown = options[:reload] || schema_has_changed?) || !loaded?
          merge_report(shutdown(options), report) if do_shutdown
          model = parse_str_schema(report, self.schema)
        else
          model = self.model
          puts "No changes detected on '#{self.name}' schema!"
        end
      rescue Exception => ex
        #raise ex
        puts "ERROR: #{errors.add(:schema, ex.message).to_s}"
        # merge_report(shutdown(options), report)
        shutdown(options)
        if previous_schema
          begin
            puts "Reloading previous schema for '#{self.name}'..."
            parse_str_schema(report, previous_schema)
            puts "Previous schema for '#{self.name}' reloaded!"
          rescue Exception => ex
            puts "ERROR: #{errors.add(:schema, 'previous version also with error: ' + ex.message).to_s}"
          end
        end
        # merge_report(shutdown(options), report)
        shutdown(options)
      end
      set_schema_ok
      self[:previous_schema] = nil
      create_default_events
      if model
        report[:loaded] << (report[:model] = model)
      else
        report[:errors][self] = errors
      end
      report
    end

    def visible
      #((Account.current ? Account.current.id : nil) == self.account.id) && self.show_navigation_link
      self.show_navigation_link
    end

    def navigation_label
      self.uri ? self.uri.library.name : nil
    end

    def create_default_events
      if self.is_object? && Setup::Observer.where(data_type: self).empty?
        puts "Creating default events for #{self.name}"
        Setup::Observer.create(data_type: self, triggers: '{"created_at":{"0":{"o":"_not_null","v":["","",""]}}}').save
        Setup::Observer.create(data_type: self, triggers: '{"updated_at":{"0":{"o":"_change","v":["","",""]}}}').save
      end
    end

    def is_object?
      self.is_object ||= merged_schema['type'] == 'object' rescue nil
      self.is_object.nil? ? false : self.is_object
    end

    def find_data_type(ref)
      (self.uri.library && self.uri.library.find_data_type_by_name(ref)) || DataType.where(name: ref).first
    end

    private

    def merge_report(report, in_to)
      in_to.deep_merge!(report) { |key, this_val, other_val| this_val + other_val }
    end

    def validate_model
      begin
        puts "Validating schema '#{self.name}'"
        json_schema = validate_schema
        self.title = json_schema['title'] || self.name if self.title.blank?
        puts "Schema '#{self.name}' validation successful!"
      rescue Exception => ex
        puts "ERROR: #{errors.add(:schema, ex.message).to_s}"
        return false
      end
      begin
        if self.sample_data && !self.sample_data.blank?
          puts 'Validating sample data...'
          Cenit::JSONSchemaValidator.validate!(self.schema, self.sample_data)
          puts 'Sample data validation successfully!'
        end
      rescue Exception => ex
        puts "ERROR: #{errors.add(:sample_data, "fails schema validation: #{ex.message} (#{ex.class})").to_s}"
        return false
      end
      return true
    end

    def schema_has_changed?
      self.previous_schema ? JSON.parse(self.previous_schema) != JSON.parse(self.schema) : true
    end

    def previous_schema_ok?
      self.schema_ok
    end

    def set_schema_ok
      self.schema_ok = true
      verify_schema_ok
    end

    def verify_schema_ok
      self.previous_schema = self.schema if previous_schema_ok?
    end

    def deconstantize(constant_name, options={})
      report = {:destroyed => Set.new, :affected => Set.new}.merge(options)
      if constant = constant_name.constantize rescue nil
        if constant.is_a?(Class)
          deconstantize_class(constant, report)
        else
          if affected_models = constant[:affected]
            affected_models.each { |model| deconstantize_class(model, report, :affected) }
          end
        end
      end
      report
    end

    def deconstantize_class(klass, report={:destroyed => Set.new, :affected => Set.new}, affected=nil)
      return report unless klass.is_a?(Module) || klass == Object
      affected = nil if report[:shutdown_all]
      if !affected && report[:affected].include?(klass)
        report[:affected].delete(klass)
        report[:destroyed] << klass
      end
      return report if report[:destroyed].include?(klass) || report[:affected].include?(klass)
      return report unless @@parsed_schemas.include?(klass.to_s) || @@parsing_schemas.include?(klass)
      parent = klass.parent
      affected = nil if report[:destroyed].include?(parent)
      puts "Reporting #{affected ? 'affected' : 'destroyed'} class #{klass.to_s} -> #{klass.schema_name rescue klass.to_s}" #" is #{affected ? 'affected' : 'in tree'} -> #{report.to_s}"
      (affected ? report[:affected] : report[:destroyed]) << klass

      unless report[:report_only] || affected
        @@parsed_schemas.delete(klass.to_s)
        @@parsing_schemas.delete(klass)
        [@@has_many_to_bind,
         @@has_one_to_bind,
         @@embeds_many_to_bind,
         @@embeds_one_to_bind].each { |to_bind| delete_pending_bindings(to_bind, klass) }
      end

      klass.constants(false).each do |const_name|
        if klass.const_defined?(const_name, false)
          const = klass.const_get(const_name, false)
          deconstantize_class(const, report, affected) if const.is_a?(Class)
        end
      end
      #[:embeds_one, :embeds_many, :embedded_in].each do |rk|
      [:embedded_in].each do |rk|
        begin
          klass.reflect_on_all_associations(rk).each do |r|
            unless report[:destroyed].include?(r.klass) || report[:affected].include?(r.klass)
              deconstantize_class(r.klass, report, :affected)
            end
          end
        rescue
        end
      end
      # relations affects if their are reflected back
      {[:embeds_one, :embeds_many] => [:embedded_in],
       [:belongs_to] => [:has_one, :has_many],
       [:has_one, :has_many] => [:belongs_to],
       [:has_and_belongs_to_many] => [:has_and_belongs_to_many]}.each do |rks, rkbacks|
        rks.each do |rk|
          klass.reflect_on_all_associations(rk).each do |r|
            rkbacks.each do |rkback|
              unless report[:destroyed].include?(r.klass) || report[:affected].include?(r.klass)
                deconstantize_class(r.klass, report, :affected) if r.klass.reflect_on_all_associations(rkback).detect { |r| r.klass.eql?(klass) }
              end
            end
          end
        end
      end
      klass.affected_models.each { |m| deconstantize_class(m, report, :affected) }
      deconstantize_class(parent, report, affected) if affected
      report
    end

    def delete_pending_bindings(to_bind, model)
      to_bind.delete_if { |property_type, _| property_type.eql?(model.to_s) }
      #to_bind.each { |property_type, a| a.delete_if { |x| x[0].eql?(model.to_s) } }
    end

    def validate_schema
      # check_type_name(self.name)
      JSON::Validator.validate!(File.read(File.dirname(__FILE__) + '/schema.json'), self.schema)
      json = JSON.parse(self.schema, :object_class => MultKeyHash)
      if json['type'] == 'object'
        check_schema(json, self.name, defined_types=[], embedded_refs=[])
        embedded_refs = embedded_refs.uniq.collect { |ref| self.name + ref }
        puts "Defined types #{defined_types.to_s}"
        puts "Embedded references #{embedded_refs.to_s}"
        embedded_refs.each { |ref| raise Exception.new(" embedded reference #/#{ref.underscore} is not defined") unless defined_types.include?(ref) }
      end
      return json
    end

    def check_schema(json, name, defined_types, embedded_refs)
      if ref=json['$ref']
        embedded_refs << check_embedded_ref(ref) if ref.start_with?('#')
      elsif json['type'].nil? || json['type'].eql?('object')
        raise Exception.new("defines multiple properties with name '#{json.mult_key_def.first.to_s}'") unless json.mult_key_def.blank?
        defined_types << name
        check_definitions(json, name, defined_types, embedded_refs)
        if properties=json['properties']
          raise Exception.new('properties specification is invalid') unless properties.is_a?(MultKeyHash)
          raise Exception.new("defines multiple properties with name '#{properties.mult_key_def.first.to_s}'") unless properties.mult_key_def.blank?
          properties.each do |property_name, property_spec|
            check_property_name(property_name)
            raise Exception.new("specification of property '#{property_name}' is not valid") unless property_spec.is_a?(Hash)
            if defined_types.include?(camelized_property_name = "#{name}::#{property_name.camelize}") && !(property_spec['$ref'] || 'object'.eql?(property_spec['type']))
              raise Exception.new("'#{name.underscore}' already defines #{property_name} (use #/[definitions|properties]/#{property_name} instead)")
            end
            check_schema(property_spec, camelized_property_name, defined_types, embedded_refs)
          end
        end
        check_requires(json)
      end
    end

    def check_embedded_ref(ref, root_name='')
      raise Exception.new("invalid format for embedded reference #{ref}") unless ref =~ /\A#(\/[a-z]+(_|([0-9]|[a-z])+)*)*\Z/
      raise Exception.new("embedding itself (referencing '#')") if ref.eql?('#')
      tokens = ref.split('/')
      tokens.shift
      type = root_name
      while !tokens.empty?
        token = tokens.shift
        raise Exception.new("use invalid embedded reference path '#{ref}'") unless %w{properties definitions}.include?(token) && !tokens.empty?
        token = tokens.shift
        type = "#{type}::#{token.camelize}"
      end
      return type
    end

    def check_requires(json)
      properties=json['properties']
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

    def check_definitions(json, parent, defined_types, embedded_refs)
      raise Exception.new("multiples definitions with name '#{json.mult_key_def.first.to_s}'") unless json.mult_key_def.blank?
      if defs=json['definitions']
        raise Exception.new('definitions format is invalid') unless defs.is_a?(MultKeyHash)
        raise Exception.new("multiples definitions with name '#{defs.mult_key_def.first.to_s}'") unless defs.mult_key_def.blank?
        defs.each do |def_name, def_spec|
          raise Exception.new("type definition '#{def_name}' is not an object type") unless def_spec.is_a?(Hash) && (def_spec['type'].nil? || def_spec['type'].eql?('object'))
          check_definition_name(def_name)
          raise Exception.new("'#{parent.underscore}/#{def_name}' definition is declared as a reference (use the reference instead)") if def_spec['$ref']
          raise Exception.new("'#{parent.underscore}' already defines #{def_name}") if defined_types.include?(camelized_def_name = "#{parent}::#{def_name.camelize}")
          check_schema(def_spec, camelized_def_name, defined_types, embedded_refs)
        end
      end
    end

    #TODO Check use
    def check_type_name(type_name)
      type_name = type_name.underscore.camelize
      # unless @@parsed_schemas.include?(model = type_name.constantize) || @@parsing_schemas.include?(model)
      #   raise Exception.new ("using type name '#{type_name}'is invalid")
      # end
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
               'string' => 'String',
               'array' => 'Array',
               'boolean' => 'Boolean',
               'date' => 'Date',
               'time' => 'Time',
               'date-time' => 'DateTime'}

    MONGO_TYPES= %w{Array BigDecimal Boolean Date DateTime Float Hash Integer Range String Symbol Time}

    @@pending_bindings
    @@has_many_to_bind = Hash.new { |h, k| h[k]=[] }
    @@has_one_to_bind = Hash.new { |h, k| h[k]=[] }
    @@embeds_many_to_bind = Hash.new { |h, k| h[k]=[] }
    @@embeds_one_to_bind = Hash.new { |h, k| h[k]=[] }
    @@parsing_schemas = Set.new
    @@parsed_schemas = Set.new

    def reflect_constant(name, value=nil, parent=nil, base_class=Object)

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
          raise "uses illegal constant #{parent.to_s}" unless @@parsing_schemas.include?(parent) || @@parsed_schemas.include?(parent.to_s) #|| parent == self.uri.library.module
        else
          return nil if do_not_create
          new_m = Class.new
          parent.const_set(token, new_m)
          parent = new_m
        end
      end

      if (parent.const_defined?(constant_name, false) rescue false)
        c = parent.const_get(constant_name)
        raise "uses illegal constant #{c.to_s}" unless @@parsed_schemas.include?(model_name) || (c.is_a?(Class) && @@parsing_schemas.include?(c))
      else
        return nil if do_not_create
        c = Class.new(base_class) unless c = value
        parent.const_set(constant_name, c)
      end
      unless do_not_create
        if c.is_a?(Class)
          puts "schema_name -> #{schema_name = (parent == Object ? self.name : parent.schema_name + '::' + constant_name)}"
          c.class_eval("def self.schema_name
            '#{schema_name}'
          end")
          puts "Created model #{c.schema_name} < #{base_class.to_s}"
          DataType.to_include_in_models.each do |module_to_include|
            unless c.include?(module_to_include)
              puts "#{c.to_s} including #{module_to_include.to_s}."
              c.include(module_to_include)
            end
          end
          DataType.to_include_in_model_classes.each do |module_to_include|
            unless c.class.include?(module_to_include)
              puts "#{c.to_s} class including #{module_to_include.to_s}."
              c.class.include(module_to_include)
            end
          end
          c.class_eval("def self.data_type
            @data_type ||= Setup::DataType.where(id: '#{self.id}').first
          end")
        else
          @@parsed_schemas << name
          puts "Created constant #{constant_name}"
        end
      end
      c
    end

    def parse_str_schema(report, str_schema)
      parse_schema(report, data_type_name, JSON.parse(str_schema), nil)
    end

    def parse_schema(report, model_name, schema, root = nil, parent=nil, embedded=nil, schema_path='')

      schema = merge_schema(schema, expand_extends: false)

      if base_model = schema.delete('extends')
        base_model_ref = base_model
        base_model = find_or_load_model(report, base_model) if base_model.is_a?(String)
        raise Exception.new("requires base model #{base_model_ref} to be already loaded") unless base_model
      end

      unless base_model.nil? || base_model.is_a?(Class)
        #Should be a schema, i.e, a Hash
        if schema['type'] == 'object' && merge_schema(base_model)['type'] != 'object'
          schema['properties'] ||= {}
          value_schema = schema['properties']['value'] || {}
          value_schema = base_model.deep_merge(value_schema)
          schema['properties']['value'] = value_schema.merge('title' => 'Value', 'xml' => {'attribute' => false})
          base_model = nil
        else
          schema = base_model.deep_merge(schema) { |key, val1, val2| array_sum(val1, val2) }
        end
      end

      klass = reflect_constant(model_name, (schema['type'] == 'object' || base_model.is_a?(Class)) ? nil : schema, parent, base_model)

      nested = []
      enums = {}
      validations = []
      required = schema['required'] || []

      unless klass.is_a?(Class)
        check_pending_binds(report, model_name, klass, root)
        return klass
      end

      model_name = klass.to_s
      reflect(klass, "def self.title
        '#{schema['title']}'
      end
      def self.schema_path
        '#{schema_path}'
      end")

      root ||= klass
      @@parsing_schemas << klass
      if @@parsed_schemas.include?(klass.to_s)
        puts "Model #{klass.to_s} already parsed"
        return klass
      end

      begin
        puts "Parsing #{klass.schema_name}"

        #TODO
        #reflect(klass, "embedded_in :#{relation_name(parent)}, class_name: \'#{parent.to_s}\'") if parent && embedded
        #klass.affects_to(parent) unless parent.nil? || parent.is_a?(Module) || parent == Object

        if definitions = schema['definitions']
          definitions.each do |def_name, def_desc|
            def_name = def_name.camelize
            puts 'Defining ' + def_name
            parse_schema(report, def_name, def_desc, root ? root : klass, klass, schema_path + "/#{definitions}/#{def_name}")
          end
        end

        if properties=schema['properties']
          raise Exception.new('properties definition is invalid') unless properties.is_a?(Hash)
          schema['properties'].each do |property_name, property_desc|
            raise Exception.new("property '#{property_name}' definition is invalid") unless property_desc.is_a?(Hash)
            check_property_name(property_name)

            v = nil
            still_trying = true
            referenced = property_desc['referenced']

            while still_trying && ref = property_desc['$ref'] # property type contains a reference
              still_trying = false
              if ref.start_with?('#') # an embedded reference
                raise Exception.new("referencing embedded reference #{ref}") if referenced
                property_type = check_embedded_ref(ref, root.to_s)
                if @@parsed_schemas.detect { |m| m.eql?(property_type) }
                  if type_model = reflect_constant(property_type, :do_not_create)
                    v = "embeds_one :#{property_name}, class_name: '#{type_model.to_s}', inverse_of: :#{relation_name(model_name, property_name)}"
                    reflect(type_model, "embedded_in :#{relation_name(model_name, property_name)}, class_name: '#{model_name}', inverse_of: :#{property_name}")
                    #type_model.affects_to(klass)
                    nested << property_name
                  else
                    raise Exception.new("refers to an invalid JSON reference '#{ref}'")
                  end
                else
                  puts "#{klass.to_s}  Waiting[3] for parsing #{property_type} to bind property #{property_name}"
                  @@embeds_one_to_bind[model_name] << [property_type, property_name]
                end
              else # an external reference
                if MONGO_TYPES.include?(ref)
                  v = "field :#{property_name}, type: #{ref}"
                else
                  # ref = check_type_name(ref)
                  if type_model = (find_or_load_model(report, ref) || reflect_constant(ref, :do_not_create))
                    if type_model.is_a?(Hash)
                      property_desc.delete('$ref')
                      property_desc = property_desc.merge(type_model)
                      bind_affect_to_relation(type_model, klass)
                      still_trying = true
                    else
                      if referenced
                        v = "belongs_to :#{property_name}, class_name: '#{type_model.to_s}'"
                        type_model.affects_to(klass)
                      else
                        v = "embeds_one :#{property_name}, class_name: '#{type_model.to_s}', inverse_of: :#{relation_name(model_name, property_name)}"
                        reflect(type_model, "embedded_in :#{relation_name(model_name, property_name)}, class_name: '#{model_name}', inverse_of: :#{property_name}")
                        #type_model.affects_to(klass)
                        nested << property_name
                      end
                    end
                  else
                    puts "#{klass.to_s}  Waiting[4]for parsing #{ref} to bind property #{property_name}"
                    (referenced ? @@has_one_to_bind : @@embeds_one_to_bind)[model_name] << [ref, property_name]
                  end
                end
              end
            end

            v = process_non_ref(report, property_name, property_desc, klass, root, nested, enums, validations, required) if still_trying

            reflect(klass, v) if v
          end
        end

        required.each do |p|
          if klass.fields.keys.include?(p) || klass.relations.keys.include?(p)
            reflect(klass, "validates_presence_of :#{p}")
          else
            [@@has_many_to_bind,
             @@has_one_to_bind,
             @@embeds_many_to_bind,
             @@embeds_one_to_bind].each do |to_bind|
              to_bind.each do |property_type, pending_bindings|
                pending_bindings.each do |binding_info|
                  binding_info << true if binding_info[1] == p
                end if property_type == klass.to_s
              end
            end
          end
        end

        validations.each { |v| reflect(klass, v) }

        schema['assertions'].each do |assertion|
          reflect(klass, "validates assertion: #{assertion}")
        end if schema['assertions']

        enums.each do |property_name, enum|
          reflect(klass, %{
          def #{property_name}_enum
            #{enum.to_s}
          end
          })
        end

        if (name = (schema['name'] || schema['title'])) && !klass.instance_methods.detect { |m| m == :name }
          reflect(klass, "def name
            #{"\"#{name}\""}
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

        @@parsed_schemas << klass.to_s

        check_pending_binds(report, model_name, klass, root)
        nested.each { |n| reflect(klass, "accepts_nested_attributes_for :#{n}") }

        @@parsing_schemas.delete(klass)

        puts "Parsing #{klass.schema_name} done!"

        return klass

      rescue Exception => ex
        @@parsing_schemas.delete(klass)
        @@parsed_schemas << klass.to_s
        raise ex
      end
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

    def bind_affect_to_relation(json_schema, model)
      puts "#{json_schema['title']} affects #{model.to_s}"
      json_schema[:affected] ||= []
      json_schema[:affected] << model
    end

    def process_non_ref(report, property_name, property_desc, klass, root, nested=[], enums={}, validations=[], required=[])

      property_desc = merge_schema(property_desc, expand_extends: false)
      model_name = klass.to_s
      still_trying = true

      while still_trying
        still_trying = false
        property_type = property_desc['type']
        if property_type == 'string' && %w{date time date-time}.include?(property_desc['format'])
          property_type = property_desc.delete('format')
        end
        property_type = RJSON_MAP[property_type] if RJSON_MAP[property_type]
        if property_type.eql?('Array') && (items_desc = property_desc['items'])
          r = nil
          ir = ''
          if referenced = ((ref = items_desc['$ref']) && (!ref.start_with?('#') && items_desc['referenced']))
            # ref = check_type_name(ref)
            if (type_model = (find_or_load_model(report, property_type = ref) || reflect_constant(ref, :do_not_create))) &&
                @@parsed_schemas.include?(type_model.to_s)
              property_type = type_model.to_s
              if (a = @@has_many_to_bind[property_type]) && i = a.find_index { |x| x[0].eql?(model_name) }
                a = a.delete_at(i)
                reflect(klass, "has_and_belongs_to_many :#{property_name}, class_name: '#{property_type}', inverse_of: #{a[1]}")
                reflect(type_model, "has_and_belongs_to_many :#{a[1]}, class_name: '#{model_name}', inverse_of: #{property_name}")
                reflect(type_model, "validates_presence_of :#{a[1]}") if a[2]
              else
                if r = type_model.reflect_on_all_associations(:belongs_to).detect { |r| r.klass.eql?(klass) }
                  r = :has_many
                else
                  r = :has_and_belongs_to_many
                  type_model.affects_to(klass)
                end
              end
            else
              puts "#{klass.to_s}  Waiting[1] for parsing #{property_type} to bind property #{property_name}"
              @@has_many_to_bind[model_name] << [property_type, property_name]
            end
          else
            r = :embeds_many
            if ref
              raise Exception.new("referencing embedded reference #{ref}") if items_desc['referenced']
              property_type = ref.start_with?('#') ? check_embedded_ref(ref, root.to_s).singularize : ref #check_type_name(ref)
              type_model = find_or_load_model(report, property_type) || reflect_constant(property_type, :do_not_create)
            else
              property_type = (type_model = parse_schema(report, property_name.camelize.singularize, property_desc['items'], root, klass, :embedded, klass.schema_path + "/properties/#{property_name}/items")).to_s
            end
            if type_model && @@parsed_schemas.detect { |m| m.eql?(property_type = type_model.to_s) }
              ir = ", inverse_of: :#{relation_name(model_name, property_name)}"
              reflect(type_model, "embedded_in :#{relation_name(model_name, property_name)}, class_name: '#{model_name}', inverse_of: :#{property_name}")
              #type_model.affects_to(klass)
              nested << property_name if r
            else
              r = nil
              puts "#{klass.to_s}  Waiting[2] for parsing #{property_type} to bind property #{property_name}"
              @@embeds_many_to_bind[model_name] << [property_type, property_name]
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
        else
          v =nil
          if property_type.eql?('object')
            if property_desc['properties'] || property_desc['extends']
              property_type = (type_model = parse_schema(report, property_name.camelize, property_desc, root, klass, :embedded, klass.schema_path + "/properties/#{property_name}")).to_s
              v = "embeds_one :#{property_name}, class_name: '#{type_model.to_s}', inverse_of: :#{relation_name(model_name, property_name)}"
              reflect(type_model, "embedded_in :#{relation_name(model_name, property_name)}, class_name: '#{model_name}', inverse_of: :#{property_name}")
              #type_model.affects_to(klass)
              nested << property_name
            else
              property_type = 'Hash'
            end
          end
          unless v
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
            if property_desc['unique']
              validations << "validates_uniqueness_in_presence_of :#{property_name}"
            end
          end
        end
      end
      return v
    end

    def check_pending_binds(report, model_name, klass, root)

      @@has_many_to_bind.each do |waiting_type, pending_binds|
        waiting_model = waiting_type.constantize rescue nil
        raise Exception.new("Waiting type #{waiting_type} not yet loaded!") unless waiting_model
        waiting_data_type = waiting_model.data_type
        raise Exception.new("Waiting type #{waiting_type} without data type!") unless waiting_data_type
        if i = pending_binds.find_index { |x| waiting_data_type.send(:find_data_type, x[0]) == self }
          waiting_ref = pending_binds[i][0]
          bindings = pending_binds.select { |x| x[0] == waiting_ref }
          pending_binds.delete_if { |x| x[0] == waiting_ref }
          bindings.each do |a|
            puts "#{waiting_model.to_s}  Binding property #{a[1]}"
            if klass.is_a?(Class)
              if klass.reflect_on_all_associations(:belongs_to).detect { |r| r.klass.eql?(waiting_model) }
                reflect(waiting_model, "has_many :#{a[1]}, class_name: \'#{model_name}\'")
              else
                reflect(waiting_model, "has_and_belongs_to_many :#{a[1]}, class_name: \'#{model_name}\'")
                klass.affects_to(waiting_model)
              end
            else #must be a json schema
              reflect(waiting_model, process_non_ref(report, a[1], klass, waiting_model, root))
              bind_affect_to_relation(klass, waiting_model)
            end
            if a[2]
              reflect(waiting_model, "validates_presence_of :#{a[1]}")
            end
          end
        end
      end

      @@has_one_to_bind.each do |waiting_type, pending_binds|
        waiting_model = waiting_type.constantize rescue nil
        raise Exception.new("Waiting type #{waiting_type} not yet loaded!") unless waiting_model
        waiting_data_type = waiting_model.data_type
        raise Exception.new("Waiting type #{waiting_type} without data type!") unless waiting_data_type
        if i = pending_binds.find_index { |x| waiting_data_type.send(:find_data_type, x[0]) == self }
          waiting_ref = pending_binds[i][0]
          bindings = pending_binds.select { |x| x[0] == waiting_ref }
          pending_binds.delete_if { |x| x[0] == waiting_ref }
          bindings.each do |a|
            puts waiting_model.to_s + '  Binding property ' + a[1]
            if klass.is_a?(Class)
              reflect(waiting_model, "belongs_to :#{a[1]}, class_name: \'#{model_name}\'")
              klass.affects_to(waiting_model)
            else #must be a json schema
              reflect(waiting_model, process_non_ref(report, a[1], klass, waiting_model, root))
              bind_affect_to_relation(klass, waiting_model)
            end
            if a[2]
              reflect(waiting_model, "validates_presence_of :#{a[1]}")
            end
          end
        end
      end

      {:embeds_many => @@embeds_many_to_bind, :embeds_one => @@embeds_one_to_bind}.each do |r, to_bind|
        to_bind.each do |waiting_type, pending_binds|
          waiting_model = waiting_type.constantize rescue nil
          raise Exception.new("Waiting type #{waiting_type} not yet loaded!") unless waiting_model
          waiting_data_type = waiting_model.data_type
          raise Exception.new("Waiting type #{waiting_type} without data type!") unless waiting_data_type
          if i = pending_binds.find_index { |x| waiting_data_type.send(:find_data_type, x[0]) == self }
            waiting_ref = pending_binds[i][0]
            bindings = pending_binds.select { |x| x[0] == waiting_ref }
            pending_binds.delete_if { |x| x[0] == waiting_ref }
            bindings.each do |a|
              puts "#{waiting_model.to_s} Binding property #{a[1]}"
              if klass.is_a?(Class)
                reflect(waiting_model, "#{r.to_s} :#{a[1]}, class_name: '#{model_name}', inverse_of: :#{relation_name(waiting_type, a[1])}")
                reflect(waiting_model, "accepts_nested_attributes_for :#{a[1]}")
                reflect(klass, "embedded_in :#{relation_name(waiting_type, a[1])}, class_name: '#{property_type}', inverse_of: :#{a[1]}")
                #klass.affects_to(waiting_model)
              else #must be a json schema
                reflect(waiting_model, process_non_ref(report, a[1], klass, waiting_model, root))
                bind_affect_to_relation(klass, waiting_model)
              end
              if a[2]
                reflect(waiting_model, "validates_presence_of :#{a[1]}")
              end
            end
          end
        end
      end
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

    class << self
      def shutdown(data_types, options={})
        return {} unless data_types
        options[:reset_config] = options[:reset_config].nil? && !options[:report_only]
        raise Exception.new("Both options 'destroy' and 'report_only' is not allowed") if options[:destroy] && options[:report_only]
        data_types = [data_types] unless data_types.is_a?(Enumerable)
        report={destroyed: Set.new, affected: Set.new, reloaded: Set.new, errors: {}}
        data_types.each do |data_type|
          begin
            r = data_type.send(:deconstantize, data_type.data_type_name, options)
            report[:destroyed] += r[:destroyed]
            report[:affected] += r[:affected]
            if options[:destroy]
              data_type.to_be_destroyed = true
              data_type.save
            end
          rescue Exception => ex
            #raise ex
            puts "Error deconstantizing model #{data_type.name}: #{ex.message}"
          end
        end
        puts "Report: #{report.to_s}"
        post_process_report(report)
        puts "Post processed report #{report}"
        unless options[:report_only]
          deconstantize(report[:destroyed])
          puts 'Reloading affected models...' unless report[:affected].empty?
          destroyed_lately = []
          report[:affected].each do |model|
            data_type = model.data_type
            unless report[:errors][data_type] ||report[:reloaded].detect { |m| m.to_s == model.to_s }
              begin
                if model.parent == Object
                  puts "Reloading #{model.schema_name rescue model.to_s} -> #{model.to_s}"
                  model_report = data_type.load_models(reload: true, reset_config: false)
                  report[:reloaded] += model_report[:reloaded] + model_report[:loaded]
                  report[:destroyed] += model_report[:destroyed]
                  if loaded_model = model_report[:model]
                    report[:reloaded] << loaded_model
                  else
                    report[:destroyed] << model
                    report[:errors][data_type] = data_type.errors
                  end
                else
                  puts "Model #{model.schema_name rescue model.to_s} -> #{model.to_s} reload on parent reload!"
                end
              rescue Exception => ex
                puts "Error deconstantizing  #{model.schema_name rescue model.to_s}"

                destroyed_lately << model
              end
              puts "Model #{model.schema_name rescue model.to_s} -> #{model.to_s} reloaded!"
            end
          end
          report[:affected].clear
          deconstantize(destroyed_lately)
          puts "Final report #{report}"
          RailsAdmin::AbstractModel.update_model_config([], report[:destroyed], report[:reloaded]) if options[:reset_config]
        end
        report
      end

      def deconstantize(models)
        models = models.sort_by do |model|
          parent = model.parent
          index = 0
          while !parent.eql?(Object)
            index = index - 1
            parent = parent.parent
          end
          index
        end
        models.each do |model|
          puts "Decontantizing #{constant_name = model.to_s} -> #{model.schema_name rescue model.to_s}"
          constant_name = constant_name.split('::').last
          model.parent.send(:remove_const, constant_name) if parent.const_defined?(constant_name)
        end
      end

      def post_process_report(report)
        affected_children =[]
        report[:affected].each { |model| affected_children << model if ancestor_included(model, report[:affected]) }
        report[:affected].delete_if { |model| report[:destroyed].include?(model) || affected_children.include?(model) }
      end

      def ancestor_included(model, container)
        parent = model.parent
        while !parent.eql?(Object)
          return true if container.include?(parent)
          parent = parent.parent
        end
        return false
      end
    end

    class MultKeyHash < Hash

      attr_reader :mult_key_def

      def initialize
        @mult_key_def = []
      end

      def store(key, value)
        @mult_key_def << key if (self[key] && !@mult_key_def.include?(key))
        super
      end

      def []=(key, value)
        @mult_key_def << key if (self[key] && !@mult_key_def.include?(key))
        super
      end
    end

    module AffectRelation

      def affected_models
        @affected_models ||= Set.new
        @affected_models.delete_if { |model| no_constant(model) }
        return @affected_models
      end

      def affects_to(model)
        puts "#{self.schema_name} affects #{model.schema_name}"
        (@affected_models ||= Set.new) << model
      end

      private

      def no_constant(model)
        model = model.to_s.constantize rescue nil
        model ? false : true
      end
    end
  end
end
