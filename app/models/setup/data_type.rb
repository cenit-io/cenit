require 'json-schema'

module Setup
  class DataType
    include Mongoid::Document
    include Mongoid::Timestamps

    class << self
      def model_listeners
        @model_listeners ||= []
      end
    end

    field :name, type: String
    field :schema, type: String
    field :sample_data, type: String

    validates_length_of :name, :maximum => 50
    validates_format_of :name, :with => /^([A-Z][a-z]*)(::([A-Z][a-z]*)+)*$/, :multiline => true
    validates_uniqueness_of :name
    validates_presence_of :schema

    before_save :validates_and_load_model
    after_save :verify_schema_ok, :create_default_events
    before_destroy :performs_destroy_model
    after_initialize :verify_schema_ok

    def load_model
      (model = validates_and_load_model(true)) ? model : nil
    end

    rails_admin do
      edit do
        field :name do
          read_only { !bindings[:object].new_record? }
          help { bindings[:object].new_record? ? 'Model name' : nil }
        end
        field :schema

        group :sample_data do
          label 'Edit sample data'
          active do
            !bindings[:object].errors.get(:sample_data).blank?
          end
        end

        field :sample_data do
          group :sample_data
        end
      end
    end

    private

    def create_default_events
      if @is_new
        puts 'Creating default events'
        Setup::Event.create(:data_type => self, :triggers => '{"created_at":{"0":{"o":"_not_null","v":["","",""]}}} ').save
        Setup::Event.create(:data_type => self, :triggers => '{"updated_at":{"0":{"o":"_change","v":["","",""]}}} ').save
      end
    end

    def validates_and_load_model(force_load=false)
      model = nil
      begin
        puts "Validating schema '#{self.name}'"
        json = validate_schema
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
        return false unless force_load
      end
      begin
        if force_load || schema_has_changed?
          unless self.new_record?
            performs_destroy_model
          end
          notify(:model_loaded, model = parse_schema(self.name, json))
        else
          puts "No changes detected on '#{self.name}' schema!"
        end
      rescue Exception => ex
        #raise ex
        puts "ERROR: #{errors.add(:schema, ex.message).to_s}"
        performs_destroy_model
        begin
          if previous_schema
            puts "Reloading previous schema for '#{self.name}'..."
            notify(:model_loaded, parse_str_schema(self.name, previous_schema))
            puts "Previous schema for '#{self.name}' reloaded!"
          else
            puts "ERROR: schema '#{self.name}' not loaded!"
          end
        rescue Exception => ex
          puts "ERROR: schema '#{self.name}' with permanent error (#{ex.message})"
        end
        performs_destroy_model
        return false
      end
      set_schema_ok
      self[:previous_schema] = nil
      @is_new = self.new_record?
      return model
    end

    def schema_has_changed?
      previous_schema ? JSON.parse(previous_schema) != JSON.parse(self.schema) : true
    end

    def previous_schema_ok?
      self[:schema_ok]
    end

    def previous_schema
      self[:previous_schema]
    end

    def set_schema_ok
      self[:schema_ok] = true
      verify_schema_ok
    end

    def verify_schema_ok
      self[:previous_schema] = self.schema if previous_schema_ok?
    end

    def notify(call_sym, model=self.name)
      return unless model
      DataType.model_listeners.each do |listener|
        begin
          puts "Notifying #{listener.to_s}.#{call_sym.to_s}(#{model.to_s})"
          listener.send(call_sym, model)
        rescue Exception => ex
          puts "'ERROR: invoking \'#{call_sym}\' on #{listener.to_s}: #{ex.message}"
        end
      end
    end

    def performs_destroy_model
      model = nil
      begin
        model = self.name.constantize
      rescue
      end
      unless model.nil?
        begin
          report = deconstantize_model(model)
          puts "Report: #{report.to_s}"
          post_process_report(report)
          puts "Post processed report #{report}"
          report[:tree].each { |model| notify(:remove_model, model) }
          report[:affected].each do |model|
            begin
              model_schema = DataType.find_by(:name => model.to_s)
              puts "Reloading #{model.to_s}"
              model_schema.load_model
            rescue
              notify(:remove_model, model)
            end
            puts "Model #{model.to_s} reloaded!"
          end
        rescue Exception => ex
          raise ex
          puts "Error destroying model #{self.name}: #{ex.message}"
        end
      end
    end

    def post_process_report(report)
      affected_children =[]
      report[:affected].each { |model, parent| affected_children << model if report[:affected].include?(parent) }
      report[:affected].delete_if { |model, _| affected_children.include?(model) }
      report[:affected] = report[:affected].keys
    end

    def deconstantize_model(model, report={:tree => Set.new, :affected => {}}, affected=nil)
      return report if report[:tree].include?(model) || report[:affected].include?(model)
      return report unless @@parsed_schemas.include?(model) || @@parsing_schemas.include?(model)
      parent = model.parent
      affected = nil if report[:tree].include?(parent)
      puts "Deconstantizing #{model.to_s}" #" is #{affected ? 'affected' : 'in tree'} -> #{report.to_s}"
      if (affected)
        report[:affected][model] = parent
      else
        report[:tree] << model
      end

      @@parsed_schemas.delete(model)
      @@parsing_schemas.delete(model)
      [@@has_many_to_bind, @@has_one_to_bind, @@embeds_many_to_bind, @@embeds_one_to_bind].each { |to_bind| delete_pending_bindings(to_bind, model) }

      model.constants(false).each do |const_name|
        if model.const_defined?(const_name, false)
          const = model.const_get(const_name, false)
          deconstantize_model(const, report, affected) if const.is_a?(Class)
        end
      end
      [:embeds_one, :embeds_many, :embedded_in].each do |rk|
        begin
          model.reflect_on_all_associations(rk).each do |r|
            deconstantize_model(r.klass, report, :affected)
          end
        rescue
        end
      end
      # referenced relations only affects if a referenced relation reflects back
      {[:belongs_to] => [:has_one, :has_many], [:has_one, :has_many] => [:belongs_to], [:has_and_belongs_to_many] => [:has_and_belongs_to_many]}.each do |rks, rkbacks|
        rks.each do |rk|
          model.reflect_on_all_associations(rk).each do |r|
            rkbacks.each do |rkback|
              deconstantize_model(r.klass, report, :affected) if r.klass.reflect_on_all_associations(rkback).detect { |r| r.klass.eql?(model) }
            end
          end
        end
      end
      model.affected_models.each { |m| deconstantize_model(m, report, :affected) }
      parent.send(:remove_const, model.to_s.split('::').last)
      return report
    end

    def delete_pending_bindings(to_bind, model)
      to_bind.delete_if { |property_type, _| property_type.eql?(model.to_s) }
      #to_bind.each { |property_type, a| a.delete_if { |x| x[0].eql?(model.to_s) } }
    end

    def validate_schema
      check_type_name(self.name)
      JSON::Validator.validate!(File.read(File.dirname(__FILE__) + '/schema.json'), self.schema)
      json = JSON.parse(self.schema, :object_class => MultKeyHash)
      raise Exception.new('is not an object type') unless json['type'].nil? || json['type'].eql?('object')
      check_schema(json, self.name, defined_types=[], embedded_refs=[])
      embedded_refs = embedded_refs.uniq.collect { |ref| self.name + ref }
      puts "Defined types #{defined_types.to_s}"
      puts "Embedded references #{embedded_refs.to_s}"
      embedded_refs.each { |ref| raise Exception.new(" embedded reference #/#{ref.underscore} is not defined") unless defined_types.include?(ref) }
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

    def check_type_name(type_name)
      begin
        unless @@parsed_schemas.include?(model = type_name.constantize) || @@parsing_schemas.include?(model)
          raise Exception.new ("using type '#{type_name}' is illegal")
        end
      rescue
      end
    end

    def check_definition_name(def_name)
      #raise Exception.new("definition name '#{def_name}' is not valid") unless def_name =~ /\A([A-Z]|[a-z])+(_|([0-9]|[a-z]|[A-Z])+)*\Z/
      raise Exception.new("definition name '#{def_name}' is not valid") unless def_name =~ /\A[a-z]+(_|([0-9]|[a-z])+)*\Z/
    end

    def check_property_name(property_name)
      raise Exception.new("property name '#{property_name}' is invalid") unless property_name =~ /\A[a-z]+(_|([0-9]|[a-z])+)*\Z/
    end

    RJSON_MAP={'string' => 'String', 'integer' => 'Integer', 'number' => 'Float', 'string' => 'String', 'array' => 'Array', 'boolean' => 'Boolean'}
    MONGO_TYPES= %w{Array BigDecimal Boolean Date DateTime Float Hash Integer Range String Symbol Time}

    @@pending_bindings
    @@has_many_to_bind = Hash.new { |h, k| h[k]=[] }
    @@has_one_to_bind = Hash.new { |h, k| h[k]=[] }
    @@embeds_many_to_bind = Hash.new { |h, k| h[k]=[] }
    @@embeds_one_to_bind = Hash.new { |h, k| h[k]=[] }
    @@parsing_schemas = Set.new
    @@parsed_schemas = Set.new

    def reflect_class(name, parent=nil, do_not_create=nil)

      tokens = name.split('::')

      class_name = tokens.pop

      unless parent || tokens.empty?
        begin
          raise "uses illegal constant #{tokens[0]}" unless (@@parsing_schemas.include?(parent = tokens[0].constantize) || @@parsed_schemas.include?(parent)) && parent.is_a?(Module)
        rescue
          return nil if do_not_create
          parent = Class.new
          Object.const_set(tokens[0], parent)
        end
        tokens.shift
      end

      tokens.each do |token|
        if parent.const_defined?(token, false)
          parent = parent.const_get(token)
          raise "uses illegal constant #{parent.to_s}" unless (@@parsing_schemas.include?(parent) || @@parsed_schemas.include?(parent)) && parent.is_a?(Module)
        else
          return nil if do_not_create
          new_m = Class.new
          parent.const_set(token, new_m)
          parent = new_m
        end
      end
      sc = MONGO_TYPES.include?(class_name) ? Object : ((parent ? parent : Object).const_get('Base') || Object)
      if (parent)
        if parent.const_defined?(class_name, false)
          c = parent.const_get(class_name)
          raise "uses illegal constant #{c.to_s}" unless (@@parsing_schemas.include?(c) || @@parsed_schemas.include?(c)) && c.is_a?(Class)
        else
          return nil if do_not_create
          c = Class.new(sc)
          parent.const_set(class_name, c)
          puts 'Created class ' + c.to_s + ' < ' + sc.to_s
        end
      else
        begin
          c = class_name.constantize
          raise "uses illegal constant #{c.to_s}" unless (@@parsing_schemas.include?(c) || @@parsed_schemas.include?(c)) && c.is_a?(Class)
        rescue
          return nil if do_not_create
          c = Class.new(sc)
          Object.const_set(class_name, c)
          puts 'Created class ' + c.to_s + ' < ' + sc.to_s
        end
      end
      unless MONGO_TYPES.include?(c.to_s)
        if c.superclass.eql?(Object) && base = (parent ? parent : Object).const_get('Base')
          puts c.to_s + ' < ' + base.to_s
          c.extend(base)
        end
        unless c.include?(Mongoid::Document) && c.include?(Mongoid::Timestamps)
          puts 'Mongonizing ' + c.to_s
          c.include Mongoid::Document unless c.include? Mongoid::Document
          c.include Mongoid::Timestamps unless c.include? Mongoid::Timestamps
        end
        # ['AfterSave'].each do |concern|
        #   if Object.const_defined?(concern) && (concern = Object.const_get(concern)).is_a?(Module)
        if c.include? AfterSave
          puts "#{c.to_s} already includes #{AfterSave.to_s}" #concern.to_s
        else
          puts "#{c.to_s} including #{AfterSave.to_s}" #concern.to_s
          c.include(AfterSave) #concern)
        end
        #   else
        #     puts "Concerns #{concern} not found!"
        #   end
        # end
        unless c.class.include?(AffectRelation)
          c.class.include AffectRelation
        end
      end
      return c
    end

    def parse_str_schema(model_name, str_schema)
      parse_schema(model_name, JSON.parse(str_schema))
    end

    def parse_schema(model_name, schema, root = nil, parent=nil, embedded=nil)

      #model_name = pick_model_name(parent) unless model_name || (model_name = schema['title'])

      klass = reflect_class(model_name, parent)

      model_name = klass.to_s

      begin

        @@parsing_schemas << klass

        if @@parsed_schemas.include?(klass)
          puts "Model #{model_name} already parsed"
          return klass
        end

        reflect(klass, "embedded_in :#{relation_name(parent)}, class_name: \'#{parent.to_s}\'") if parent && embedded

        root ||= klass;

        puts "Parsing #{model_name}"

        if definitions = schema['definitions']
          definitions.each do |def_name, def_desc|
            def_name = def_name.camelize
            puts 'Defining ' + def_name
            parse_schema(def_name, def_desc, root ? root : klass, klass)
          end
        end

        nested = []
        validations = []
        enums = {}

        if properties=schema['properties']
          raise Exception.new('properties definition is invalid') unless properties.is_a?(Hash)
          schema['properties'].each do |property_name, property_desc|
            raise Exception.new("property '#{property_name}' definition is invalid") unless property_desc.is_a?(Hash)
            check_property_name(property_name)
            v = nil
            if ref = property_desc['$ref'] # property type is a reference
              if ref.start_with?('#')
                property_type = check_embedded_ref(ref, root.to_s)
                if @@parsed_schemas.detect { |m| m.to_s.eql?(property_type) }
                  if type_model = reflect_class(property_type, nil, :do_not_create)
                    v = "embeds_one :#{property_name}, class_name: \'#{type_model.to_s}\'"
                    reflect(type_model, "embedded_in :#{relation_name(model_name)}, class_name: \'#{model_name}\'")
                    nested << property_name
                  else
                    raise Exception.new("refers to an invalid JSON reference '#{ref}'")
                  end
                else
                  puts "#{klass.to_s}  Waiting for parsing #{property_type} to bind property #{property_name}"
                  @@embeds_one_to_bind[model_name] << [property_type, property_name]
                end
              else
                if MONGO_TYPES.include?(ref)
                  v = "field :#{property_name}, type: #{ref}"
                else
                  check_type_name(ref)
                  if type_model = reflect_class(ref, nil, :do_not_create)
                    v = "belongs_to :#{property_name}, class_name: \'#{ref}\'"
                    type_model.affects_to(klass)
                  else
                    puts "#{klass.to_s}  Waiting for parsing #{ref} to bind property #{property_name}"
                    @@has_one_to_bind[model_name] << [ref, property_name]
                  end
                end
              end
            else
              unless property_type = property_desc['type']
                property_type = 'object'
              end
              property_type = RJSON_MAP[property_type] if RJSON_MAP[property_type]
              if property_type.eql?('Array') && property_desc['items']
                r = nil
                if referenced = ((ref = property_desc['items']['$ref']) && !ref.start_with?('#'))
                  check_type_name(ref)
                  if @@parsed_schemas.include?(type_model = reflect_class(property_type = ref, nil, :do_not_create))
                    puts "#{klass.to_s}  Binding property #{property_name}"
                    if (a = @@has_many_to_bind[property_type]) && i = a.find_index { |x| x[0].eql?(model_name) }
                      a = a.delete_at(i)
                      reflect(klass, "has_and_belongs_to_many :#{property_name}, class_name: \'#{property_type}\'")
                      reflect(type_model, "has_and_belongs_to_many :#{a[1]}, class_name: \'#{model_name}\'")
                    else
                      if type_model.reflect_on_all_associations(:belongs_to).detect { |r| r.klass.eql?(klass) }
                        r = 'has_many'
                      else
                        r = 'has_and_belongs_to_many'
                        type_model.affects_to(klass)
                      end
                    end
                  else
                    puts "#{klass.to_s}  Waiting for parsing #{property_type} to bind property #{property_name}"
                    @@has_many_to_bind[model_name] << [property_type, property_name]
                  end
                else
                  r = 'embeds_many'
                  if ref
                    property_type = check_embedded_ref(ref, root.to_s).singularize
                    if @@parsed_schemas.detect { |m| m.to_s.eql?(property_type) }
                      if type_model = reflect_class(property_type, nil, :do_not_create)
                        reflect(type_model, "embedded_in :#{relation_name(model_name)}, class_name: \'#{type_model.to_s}\'")
                      else
                        raise Exception.new("refers to an invalid JSON reference '#{ref}'")
                      end
                    else
                      r = nil
                      puts "#{klass.to_s}  Waiting for parsing #{property_type} to bind property #{property_name}"
                      @@embeds_many_to_bind[model_name] << [property_type, property_name]
                    end
                  else
                    property_type = (type_model = parse_schema(property_name.camelize.singularize, property_desc['items'], root, klass, :embedded)).to_s
                  end
                  nested << property_name if r
                end
                if r
                  v = "#{r} :#{property_name}, class_name: \'#{property_type.to_s}\'"
                  # embedded_in relation reflected before if ref or it is reflected when parsing with :embedded option
                  #reflect(type_model, "#{referenced ? 'belongs_to' : 'embedded_in'} :#{relation_name(model_name)}, class_name: \'#{model_name}\'")
                  #reflect(type_model, "belongs_to :#{relation_name(model_name)}, class_name: '#{model_name}'") if referenced
                end
              else
                v =nil
                if property_type.eql?('object')
                  if property_desc['properties']
                    property_type = (type_model = parse_schema(property_name.camelize, property_desc, root, klass, :embedded)).to_s
                    v = "embeds_one :#{property_name}, class_name: \'#{type_model.to_s}\'"
                    #reflect(type_model, "embedded_in :#{relation_name(model_name)}, class_name: \'#{model_name}\'")
                    nested << property_name
                  else
                    property_type = 'Hash'
                  end
                end
                unless v
                  v = "field :#{property_name}, type: #{property_type}"
                  if property_desc['default']
                    v += ", default: \'#{property_desc['default']}\'"
                  end
                  if property_type.eql?('String')
                    if property_desc['minLength'] || property_desc['maxLength']
                      validations << "validates_length_of :#{property_name}#{property_desc['minLength'] ? ', :minimum => ' + property_desc['minLength'].to_s : ''}#{property_desc['maxLength'] ? ', :maximum => ' + property_desc['maxLength'].to_s : ''}"
                    end
                    if property_desc['pattern']
                      validations << "validates_format_of :#{property_name}, :with => /#{property_desc['pattern']}/i"
                    end
                  end
                  if property_type.eql?('Float') || property_type.eql?('Integer')
                    constraints = []
                    if property_desc['minimum']
                      constraints << (property_desc['exclusiveMinimum'] ? 'greater_than: ' : 'greater_than_or_equal_to: ') + property_desc['minimum'].to_s
                    end
                    if property_desc['maximum']
                      constraints << (property_desc['exclusiveMaximum'] ? 'less_than: ' : 'less_than_or_equal_to: ') + property_desc['maximum'].to_s
                    end
                    if constraints.length > 0
                      validations << "validates_numericality_of :#{property_name}, {#{constraints[0] + (constraints[1] ? ', ' + constraints[1] : '')}}"
                    end
                  end
                  if property_desc['unique']
                    validations << "validates_uniqueness_of :#{property_name}"
                  end
                  if enum = property_desc['enum']
                    enums[property_name] = enum
                  end
                end
              end
            end
            reflect(klass, v) if v
          end
        end

        if r = schema['required']
          v = "validates_presence_of :#{r.shift}"
          r.each { |p| v += ', :' + p }
          reflect(klass, v)
        end

        validations.each { |v| reflect(klass, v) }

        enums.each do |property_name, enum|
          reflect(klass, %{
          def #{property_name}_enum
            #{enum.to_s}
          end
          })
        end

        @@parsed_schemas << klass

        @@has_many_to_bind.each do |property_type, a|
          if i = a.find_index { |x| x[0].eql?(model_name) }
            a = a.delete_at(i)
            puts "#{(type_model = reflect_class(property_type)).to_s}  Binding property #{a[1]}"
            if klass.reflect_on_all_associations(:belongs_to).detect { |r| r.klass.eql?(type_model) }
              reflect(type_model, "has_many :#{a[1]}, class_name: \'#{model_name}\'")
            else
              reflect(type_model, "has_and_belongs_to_many :#{a[1]}, class_name: \'#{model_name}\'")
              klass.affects_to(type_model)
            end
          end
        end

        @@has_one_to_bind.each do |property_type, pending_binds|
          if i = pending_binds.find_index { |x| x[0].eql?(model_name) }
            a = pending_binds.delete_at(i)
            puts (type_model = reflect_class(property_type)).to_s + '  Binding property ' + a[1]
            reflect(type_model, "belongs_to :#{a[1]}, class_name: \'#{model_name}\'")
            klass.affects_to(type_model)
          end
        end

        {:embeds_many => @@embeds_many_to_bind, :embeds_one => @@embeds_one_to_bind}.each do |r, to_bind|
          to_bind.each do |property_type, pending_binds|
            if i = pending_binds.find_index { |x| x[0].eql?(model_name) }
              a = pending_binds.delete_at(i)
              puts (type_model = reflect_class(property_type)).to_s + '  Binding property ' + a[1]
              reflect(type_model, "#{r.to_s} :#{a[1]}, class_name: \'#{model_name}\'")
              reflect(type_model, "accepts_nested_attributes_for :#{a[1]}")
              reflect(klass, "embedded_in :#{property_type.underscore.split('/').join('_')}, class_name: '#{property_type}'")
            end
          end
        end

        nested.each { |n| reflect(klass, "accepts_nested_attributes_for :#{relation_name(n)}") }

        @@parsing_schemas.delete(klass)

        puts "Parsing #{model_name} done!"

        return klass

      rescue Exception => ex
        @@parsing_schemas.delete(klass)
        @@parsed_schemas << klass
        raise ex
      end
    end

    def relation_name(model)
      model.to_s.underscore.split('/').join('_')
    end

    # def pick_model_name(parent_module)
    #   parent_module ||= Object
    #   i = 1
    #   model_name = 'Model'
    #   while parent_module.const_defined?(model_name)
    #     model_name = 'Model' + (i=i+1).to_s
    #   end
    #   return model_name
    # end

    def reflect(c, code)
      puts "#{c.to_s}  #{code}"
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
      end

      def affects_to(model)
        puts "#{self.to_s} affects #{model.to_s}"
        (@affected_models ||= Set.new)<< model
      end
    end
  end
end