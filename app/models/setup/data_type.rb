require 'edi/formater'

module Setup
  class DataType < BaseDataType
    include CenitScoped

    Setup::Models.exclude_actions_for self, :delete, :new, :bulk_delete, :delete_all, :update, :edit

    BuildInDataType.regist(self).referenced_by(:name)

    def self.to_include_in_models
      @to_include_in_models ||= [Mongoid::Document,
                                 Mongoid::Timestamps,
                                 Setup::ClassAffectRelation,
                                 Mongoid::CenitExtension,
                                 EventLookup,
                                 AccountScoped,
                                 DynamicValidators,
                                 Edi::Formatter,
                                 Edi::Filler,
                                 RailsAdminDynamicCharts::Datetime]
    end

    belongs_to :schema, class_name: Setup::Schema.to_s, inverse_of: :data_types

    field :title, type: String
    field :name, type: String
    field :model_schema, type: String

    has_many :events, class_name: Setup::Event.to_s, dependent: :destroy, inverse_of: :data_type
    #TODO Check dependent behavior with flows
    #has_many :flows, class_name: Setup::Flow.name, dependent: :destroy, inverse_of: :data_type

    validates_presence_of :name, :model_schema

    before_save :validate_model
    before_destroy :delete_all

    field :is_object, type: Boolean
    field :activated, type: Boolean, default: false
    field :show_navigation_link, type: Boolean
    field :to_be_destroyed, type: Boolean
    field :used_memory, type: BigDecimal, default: 0
    field :model_loaded, type: Boolean

    scope :activated, -> { where(activated: true) }

    def shutdown(options={})
      DataType.shutdown(self, options)
    end

    def model
      data_type_name.constantize rescue nil
    end

    def records_model
      (m = model) && m.is_a?(Class) ? m : @mongoff_model ||= Mongoff::Model.new(self)
    end

    def loaded?
      model ? true : false
    end

    def data_type_name
      "Dt#{self.id.to_s}"
    end

    def collection_size(scale=1)
      records_model.collection_size(scale)
    end

    def count
      records_model.count
    end

    def delete_all
      if  m = records_model
        m.delete_all
      end
    end

    def shutdown_model(options={})
      report = deconstantize(data_type_name, options)
      unless options[:report_only]
        self.to_be_destroyed = true if options[:destroy]
        self.used_memory = 0
        self.model_loaded = false
        save
      end
      report
    end

    def to_be_destroyed?
      to_be_destroyed
    end

    def load_model(options={})
      load_models(options)[:model]
    end

    def load_models(options={reload: false, reset_config: true})
      reload
      do_activate = options.delete(:activated) || activated
      report = {loaded: Set.new, errors: {}}
      begin
        model =
          if (do_shutdown = options[:reload]) || !loaded?
            merge_report(shutdown(options), report) if do_shutdown
            parse_str_schema(report, self.model_schema)
          else
            self.model
          end
      rescue Exception => ex
        #TODO Delete raise
        #raise ex
        puts "ERROR: #{errors.add(:model_schema, ex.message).to_s}"
        # merge_report(shutdown(options), report)
        shutdown(options)
      end
      create_default_events
      if model
        report[:loaded] << (report[:model] = model)
        if self.used_memory != (model_used_memory = RailsAdmin::Config::Actions::MemoryUsage.of(model))
          self.used_memory = model_used_memory
        end
        report[:destroyed].delete_if { |m| m.to_s == model.to_s } if report[:destroyed]
        self.activated = do_activate if do_activate.present?
        self.model_loaded = true
      else
        report[:errors][self] = errors
        self.used_memory = 0 unless self.used_memory == 0
        self.activated = false
        self.model_loaded = false
      end
      save
      report
    end

    def visible
      #((Account.current ? Account.current.id : nil) == self.account.id) && self.show_navigation_link
      self.show_navigation_link
    end

    def navigation_label
      self.schema ? self.schema.library.name : nil
    end

    def create_default_events
      if self.is_object? && Setup::Observer.where(data_type: self).empty?
        puts "Creating default events for #{self.name}"
        Setup::Observer.create(data_type: self, triggers: '{"created_at":{"0":{"o":"_not_null","v":["","",""]}}}')
        Setup::Observer.create(data_type: self, triggers: '{"updated_at":{"0":{"o":"_change","v":["","",""]}}}')
      end
    end

    def is_object?
      is_object.present?
    end

    def find_data_type(ref)
      #TODO Are data types referenced only in libray scope?
      (self.schema.library && self.schema.library.find_data_type_by_name(ref)) #|| DataType.where(name: ref).first
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
        #TODO Remove raise
        #raise ex
        puts "ERROR: #{errors.add(:model_schema, ex.message).to_s}"
      end
      sch = merged_schema rescue nil
      unless self.is_object = sch && sch['type'] == 'object' && !sch['properties'].nil?
        self.activated = false
      end
      errors.blank?
    end

    def deconstantize(constant_name, options={})
      report = {:destroyed => Set.new, :affected => Set.new}.merge(options)
      if constant = constant_name.constantize rescue nil
        if constant.is_a?(Class)
          deconstantize_class(constant, report)
        else # it is a Mongoff model
          constant.affected_models.each { |model| deconstantize_class(model, report, :affected) }
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
      JSON::Validator.validate!(File.read(File.dirname(__FILE__) + '/schema.json'), self.model_schema)
      json = JSON.parse(self.model_schema, :object_class => MultKeyHash)
      if json['type'] == 'object'
        check_schema(json, self.name, defined_types=[], embedded_refs=[])
        embedded_refs = embedded_refs.uniq.collect { |ref| self.name + ref }
        puts "Defined types #{defined_types.to_s}"
        puts "Embedded references #{embedded_refs.to_s}"
        embedded_refs.each { |ref| raise Exception.new(" embedded reference #/#{ref.underscore} is not defined") unless defined_types.include?(ref) }
      end
      json
    end

    def check_schema(json, name, defined_types, embedded_refs)
      if ref = json['$ref']
        embedded_refs << check_embedded_ref(ref) if ref.start_with?('#')
      elsif json['type'].nil? || json['type'].eql?('object')
        raise Exception.new("defines multiple properties with name '#{json.mult_key_def.first.to_s}'") if json.mult_key_def.present?
        defined_types << name
        check_definitions(json, name, defined_types, embedded_refs)
        if properties = json['properties']
          raise Exception.new('properties specification is invalid') unless properties.is_a?(MultKeyHash)
          raise Exception.new("defines multiple properties with name '#{properties.mult_key_def.first.to_s}'") if properties.mult_key_def.present?
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
      while tokens.present?
        token = tokens.shift
        raise Exception.new("use invalid embedded reference path '#{ref}'") unless %w{properties definitions}.include?(token) && !tokens.empty?
        token = tokens.shift
        type = "#{type}::#{token.camelize}"
      end
      type
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

    def check_definitions(json, parent, defined_types, embedded_refs)
      raise Exception.new("multiples definitions with name '#{json.mult_key_def.first.to_s}'") if json.mult_key_def.present?
      if defs = json['definitions']
        raise Exception.new('definitions format is invalid') unless defs.is_a?(MultKeyHash)
        raise Exception.new("multiples definitions with name '#{defs.mult_key_def.first.to_s}'") if defs.mult_key_def.present?
        defs.each do |def_name, def_spec|
          raise Exception.new("type definition '#{def_name}' is not an object type") unless def_spec.is_a?(Hash) && (def_spec['type'].nil? || def_spec['type'].eql?('object'))
          check_definition_name(def_name)
          raise Exception.new("'#{parent.underscore}/#{def_name}' definition is declared as a reference (use the reference instead)") if def_spec['$ref']
          raise Exception.new("'#{parent.underscore}' already defines #{def_name}") if defined_types.include?(camelized_def_name = "#{parent}::#{def_name.camelize}")
          check_schema(def_spec, camelized_def_name, defined_types, embedded_refs)
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

    @@pending_bindings
    @@has_many_to_bind = Hash.new { |h, k| h[k]=[] }
    @@has_one_to_bind = Hash.new { |h, k| h[k]=[] }
    @@embeds_many_to_bind = Hash.new { |h, k| h[k]=[] }
    @@embeds_one_to_bind = Hash.new { |h, k| h[k]=[] }
    @@parsing_schemas = Set.new
    @@parsed_schemas = Set.new

    def object_schema?(schema)
      schema['type'] == 'object' && schema['properties']
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
          raise "uses illegal constant #{parent.to_s}" unless @@parsing_schemas.include?(parent) || @@parsed_schemas.include?(parent.to_s) #|| parent == self.schema.library.module
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
        c = Class.new(base_class) unless value && c = Mongoff::Model.new(self)
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
          # DataType.to_include_in_model_classes.each do |module_to_include|
          #   unless c.class.include?(module_to_include)
          #     puts "#{c.to_s} class including #{module_to_include.to_s}."
          #     c.class.include(module_to_include)
          #   end
          # end
          c.class_eval("def self.data_type
            Setup::DataType.where(id: '#{self.id}').first
          end
          def orm_model
            self.class
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

    def parse_schema(report, model_name, schema, root = nil, parent = nil, embedded = nil, schema_path = '')

      schema = merge_schema(schema, expand_extends: false)

      base_model = nil
      if (base_schema = schema.delete('extends')) && base_schema.is_a?(String)
        if base_model = find_or_load_model(report, base_schema)
          base_schema = base_model.data_type.merged_schema
        else
          raise Exception.new("requires base model #{base_schema} to be already loaded")
        end
      end

      if base_schema && !base_model.is_a?(Class)
        if schema['type'] == 'object' && base_schema['type'] != 'object'
          schema['properties'] ||= {}
          value_schema = schema['properties']['value'] || {}
          value_schema = base_schema.deep_merge(value_schema)
          schema['properties']['value'] = value_schema.merge('title' => 'Value', 'xml' => {'attribute' => false})
        else
          schema = base_schema.deep_merge(schema) { |key, val1, val2| array_sum(val1, val2) }
        end
      end

      klass = reflect_constant(model_name, (object_schema?(schema) || base_model.is_a?(Class)) ? nil : schema, parent, base_model.is_a?(Class) ? base_model : nil)
      base_model.affects_to(klass) if base_model

      nested = []
      enums = {}
      validations = []
      required = schema['required'] || []

      unless klass.is_a?(Class)
        #is a Mongoff model
        check_pending_binds(report, model_name, klass, root)
        return klass
      end

      model_name = klass.model_access_name

      reflect(klass, "def self.title
        '#{schema['title']}'
      end
      def self.schema_path
        '#{schema_path}'
      end")

      root ||= klass
      @@parsing_schemas << klass
      if @@parsed_schemas.include?(model_name)
        puts "Model #{model_name} already parsed"
        return klass
      end

      begin
        puts "Parsing #{klass.schema_name}"

        if definitions = schema['definitions']
          definitions.each do |key, def_desc|
            def_name = key.camelize
            puts 'Defining ' + def_name
            parse_schema(report, def_name, def_desc, root ? root : klass, klass, :embedded, "#{schema_path}/definitions/#{key}")
          end
        end

        if properties = schema['properties']
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
                property_type = check_embedded_ref(ref, root.model_access_name)
                if @@parsed_schemas.detect { |m| m.eql?(property_type) }
                  if type_model = reflect_constant(property_type, :do_not_create)
                    v = "embeds_one :#{property_name}, class_name: '#{type_model.to_s}', inverse_of: :#{relation_name(model_name, property_name)}"
                    reflect(type_model, "embedded_in :#{relation_name(model_name, property_name)}, class_name: '#{model_name}', inverse_of: :#{property_name}")
                    nested << property_name
                  else
                    raise Exception.new("refers to an invalid JSON reference '#{ref}'")
                  end
                else
                  puts "#{klass.to_s}  Waiting [3] for parsing #{property_type} to bind property #{property_name}"
                  @@embeds_one_to_bind[model_name] << [property_type, property_name]
                end
              else # an external reference
                if MONGO_TYPES.include?(ref)
                  v = "field :#{property_name}, type: #{ref}"
                else
                  if type_model = (find_or_load_model(report, ref) || reflect_constant(ref, :do_not_create))
                    unless type_model.is_a?(Class)
                      #is a Mongoff model
                      property_desc.delete('$ref')
                      property_desc = property_desc.merge(JSON.parse(type_model.data_type.model_schema))
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
                pending_bindings.each { |binding_info| binding_info << true if binding_info[1] == p } if property_type == klass.to_s
              end
            end
          end
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

    def process_non_ref(report, property_name, property_desc, klass, root, nested=[], enums={}, validations=[], required=[])

      property_desc = merge_schema(property_desc, expand_extends: false)
      model_name = klass.model_access_name
      still_trying = true

      while still_trying
        still_trying = false
        property_type = property_desc['type']
        if property_type == 'string' && %w{date time date-time}.include?(property_desc['format'])
          property_type = property_desc.delete('format')
        end
        property_type = RJSON_MAP[property_type] if RJSON_MAP[property_type]
        if property_type.eql?('Array') && (items_desc = property_desc['items'])
          #TODO Check when type model is a Mongoff model
          r = nil
          ir = ''
          if referenced = ((ref = items_desc['$ref']) && (!ref.start_with?('#') && items_desc['referenced']))
            if (type_model = (find_or_load_model(report, property_type = ref) || reflect_constant(ref, :do_not_create))) &&
              @@parsed_schemas.include?(type_model.model_access_name)
              property_type = type_model.model_access_name
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
                  ir = ', inverse_of: nil'
                  type_model.affects_to(klass)
                end
              end
            else
              puts "#{klass.to_s}  Waiting [1] for parsing #{property_type} to bind property #{property_name}"
              @@has_many_to_bind[model_name] << [property_type, property_name]
            end
          else
            r = :embeds_many
            if ref
              raise Exception.new("referencing embedded reference #{ref}") if items_desc['referenced']
              property_type = ref.start_with?('#') ? check_embedded_ref(ref, root.to_s).singularize : ref
              type_model = find_or_load_model(report, property_type) || reflect_constant(property_type, :do_not_create)
            else
              property_type = (type_model = parse_schema(report, property_name.camelize.singularize, property_desc['items'], root, klass, :embedded, klass.schema_path + "/properties/#{property_name}/items")).model_access_name
            end
            if type_model && @@parsed_schemas.detect { |m| m.eql?(property_type = type_model.to_s) }
              ir = ", inverse_of: :#{relation_name(model_name, property_name)}"
              reflect(type_model, "embedded_in :#{relation_name(model_name, property_name)}, class_name: '#{model_name}', inverse_of: :#{property_name}")
              nested << property_name if r
            else
              r = nil
              puts "#{klass.to_s}  Waiting [2] for parsing #{property_type} to bind property #{property_name}"
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
              property_type = (type_model = parse_schema(report, property_name.camelize, property_desc, root, klass, :embedded, klass.schema_path + "/properties/#{property_name}")).model_access_name
              v = "embeds_one :#{property_name}, class_name: '#{type_model.to_s}', inverse_of: :#{relation_name(model_name, property_name)}"
              reflect(type_model, "embedded_in :#{relation_name(model_name, property_name)}, class_name: '#{model_name}', inverse_of: :#{property_name}")
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
      v
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
                reflect(waiting_model, "has_and_belongs_to_many :#{a[1]}, class_name: \'#{model_name}\', inverse_of: nil")
                klass.affects_to(waiting_model)
              end
            else #is a Mongoff model
              reflect(waiting_model, process_non_ref(report, a[1], klass, waiting_model, root))
              klass.affects_to(waiting_model)
            end
            reflect(waiting_model, "validates_presence_of :#{a[1]}") if a[2]
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
            else #is a Mongoff model
              reflect(waiting_model, process_non_ref(report, a[1], klass, waiting_model, root))
              klass.affects_to(waiting_model)
            end
            reflect(waiting_model, "validates_presence_of :#{a[1]}") if a[2]
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
                reflect(klass, "embedded_in :#{relation_name(waiting_type, a[1])}, class_name: '#{waiting_type}', inverse_of: :#{a[1]}")
                #klass.affects_to(waiting_model)
              else #is a Mongoff model
                reflect(waiting_model, process_non_ref(report, a[1], klass, waiting_model, root))
                klass.affects_to(waiting_model)
              end
              reflect(waiting_model, "validates_presence_of :#{a[1]}") if a[2]
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
        report = {destroyed: Set.new, affected: Set.new, reloaded: Set.new, errors: {}}
        data_types.each do |data_type|
          begin
            r = data_type.shutdown_model(options)
            report[:destroyed] += r[:destroyed]
            report[:affected] += r[:affected]
          rescue Exception => ex
            raise ex
            puts "Error deconstantizing model #{data_type.name}: #{ex.message}"
          end
        end
        puts "Report: #{report.to_s}"
        post_process_report(report)
        puts "Post processed report #{report}"
        unless options[:report_only]
          report[:destroyed].each do |model|
            model.data_type.shutdown_model(options) unless data_types.include?(data_type = model.data_type)
          end
          deconstantize(report[:destroyed])
          puts 'Reloading affected models...' if report[:affected].present?
          destroyed_lately = []
          report[:affected].each do |model|
            data_type = model.data_type
            unless report[:errors][data_type] || report[:reloaded].detect { |m| m.to_s == model.to_s }
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
                raise ex
                puts "Error deconstantizing  #{model.schema_name rescue model.to_s}"
                destroyed_lately << model
              end
              puts "Model #{model.schema_name rescue model.to_s} -> #{model.to_s} reloaded!"
            end
          end
          report[:affected].clear
          deconstantize(destroyed_lately)
          report[:destroyed].delete_if { |model| report[:reloaded].detect { |m| m.to_s == model.to_s } }
          puts "Final report #{report}"
          RailsAdmin::AbstractModel.update_model_config([], report[:destroyed], report[:reloaded]) if options[:reset_config]
        end
        report
      end

      def deconstantize(models)
        models = models.sort_by do |model|
          index = 0
          if model.is_a?(Class)
            parent = model.parent
            while !parent.eql?(Object)
              index = index - 1
              parent = parent.parent
            end
          end
          index
        end
        models.each do |model|
          puts "Decontantizing #{constant_name = model.model_access_name} -> #{model.schema_name rescue model.to_s}"
          constant_name = constant_name.split('::').last
          parent = model.is_a?(Class) ? model.parent : Object
          parent.send(:remove_const, constant_name) if parent.const_defined?(constant_name)
        end
      end

      def post_process_report(report)
        report[:affected].each do |model|
          unless model.affected_models.detect { |m| !report[:destroyed].include?(m) }
            report[:destroyed] << model
            report[:affected].delete(model)
          end
        end

        to_destroy_also = Set.new
        report[:destroyed].each do |model|
          model.affected_by.each do |m|
            unless report[:destroyed].include?(m) || (affected = m.try(:affected_models)).nil? || affected.detect { |m2| !report[:destroyed].include?(m2) }
              to_destroy_also << m
            end
          end
        end
        report[:destroyed] += to_destroy_also

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
        false
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
  end
end