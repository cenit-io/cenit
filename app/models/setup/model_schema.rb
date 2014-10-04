module Setup
  class ModelSchema
    include Mongoid::Document
    include Mongoid::Timestamps

    field :module_name, type: String, default: 'Hub'
    field :name, type: String
    field :after_save_callback, type: Boolean, default: false
    field :schema, type: String

    validates_presence_of :module_name, :name, :schema
    validates_length_of :module_name, :maximum => 50
    validates_format_of :module_name, :with => /^([A-Z]+[a-z]*)+(::([A-Z]+[a-z]*)+)*$/, :multiline => true
    validates_length_of :name, :maximum => 50
    validates_format_of :module_name, :with => /^([A-Z]+[a-z]*)+$/, :multiline => true

    before_save :validates_and_load_model

    def model
      [self.module_name, self.name].join('::').constantize
    end

    def load_model
      m = nil
      if self.after_save_callback
        begin
          m = (self.module_name + '::AfterSave').constantize
        rescue
        end
      end
      ModelSchema.parse_str_schema(self.schema, m ? [m] : [])
    end

    protected

    def validates_and_load_model
      hash = JSON.parse(self.schema)
      required_title = self.module_name + '::' + self.name
      if title = hash['title']
        if !title.eql?(required_title)
          self.errors.add(:schema, 'title \'' + required_title + '\' expected, but \'' + title + '\' found.')
          return false
        end
      else
        hash['title'] = required_title
        self.schema = hash.to_json
      end
      RailsAdmin::AbstractModel.regist_model(load_model)
    end

    class << self

      MONGO_TYPES=['Array', 'BigDecimal', 'Boolean', 'Date', 'DateTime', 'Float', 'Hash', 'Integer', 'Range', 'String', 'Symbol', 'Time']

      @@has_many_to_bind = {}
      @@parsed_schemas = []

      def reflect_class(name, to_include=[])

        tokens = name.split("::")

        class_name = tokens.pop

        m = nil

        if !tokens.empty?
          begin
            m = tokens[0].constantize
          rescue
            m = Module.new
            Object.const_set(tokens[0], m)
          end
          tokens.shift
        end

        tokens.each do|token|
          if m.const_defined?(token)
            m = m.const_get(token)
          else
            new_m = Module.new
            m.const_set(token, new_m)
            m = new_m
          end
        end

        if (m)
          if !m.const_defined?(class_name)
            c = Class.new
            eval(name + ' = c')
          else
            c = m.const_get(class_name)
          end
        else
          begin
            c = class_name.constantize
          rescue
            c = Class.new
            eval(name + ' = c')
          end
        end
        if !MONGO_TYPES.include?(c.name.capitalize) && (!c.include?(Mongoid::Document) || !(c.include? Mongoid::Timestamps))
          puts 'Mongonizing ' + c.to_s
          c.include Mongoid::Document unless c.include? Mongoid::Document
          c.include Mongoid::Timestamps unless c.include? Mongoid::Timestamps
        end
        to_include && to_include.each do |m|
          if !c.include?(m)
            puts 'Including ' + m.to_s
            c.include m
          end
        end
        return c
      end

      def parse_str_schema(str_schema, to_include=[])
        parse_schema(JSON.parse(str_schema), to_include)
      end

      protected

      def parse_schema(schema, to_include=[])

        c= reflect_class(model_name = schema['title'], to_include)

        return c if @@parsed_schemas.include?(model_name)

        puts 'parsing ' + model_name

        nested = []
        validations = []

        if schema['properties']
          schema['properties'].each do |property_name, property_desc|
            v = nil
            type_model = reflect_class(property_type = property_desc['type'])
            if MONGO_TYPES.include?(property_type) && !(property_type.eql?('Array') && property_desc['items'])
              v = 'field :' + property_name + ', type: ' + property_desc['type']
              if property_desc['default']
                v += ', default: \'' + property_desc['default'] + '\''
              end
              if property_type.eql?('String')
                if property_desc['minLength'] || property_desc['minLength']
                  validations << ('validates_length_of :' + property_name + (property_desc['minLength'] ? ', :minimum => ' + property_desc['minLength'].to_s : '') + (property_desc['maxLength'] ? ', :maximum => ' + property_desc['maxLength'].to_s : ''))
                end
                if property_desc['pattern']
                  validations << ('validates_format_of :' + property_name + ', :with => /' + property_desc['pattern'] + '/i')
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
                  validations << 'validates_numericality_of :' + property_name + ', {' + constraints[0] + (constraints[1] ? ', ' + constraints[1] : '') + '}'
                end
              end
              if property_desc['unique']
                validations << 'validates_uniqueness_of :' + property_name
              end
            else
              nested << property_name if embedded = property_desc['embedded'].nil? || property_desc['embedded']
              r = nil
              if property_type.eql?('Array')
                type_model = reflect_class(property_type = property_desc['items']['type'])
                if embedded
                  r =  'embeds_many'
                else
                  if @@parsed_schemas.include?(property_type)
                    puts c.to_s + '  Binding property ' + property_name
                    if (a = @@has_many_to_bind[property_type]) && i = a.find_index {|x| x[0].eql?(model_name)}
                      a = a.delete_at(i)
                      reflect(c, 'has_and_belongs_to_many :' + property_name + ', class_name: \'' + property_type + '\'')
                      reflect(type_model, 'has_and_belongs_to_many :' + a[1] + ', class_name: \'' + model_name + '\'')
                    else
                      r = 'has_many'
                    end
                  else
                    puts c.to_s + '  Waiting for parsing ' + property_type + ' to bind property ' + property_name
                    @@has_many_to_bind[model_name] = [] if @@has_many_to_bind[model_name].nil?
                    @@has_many_to_bind[model_name] << [property_type, property_name]
                  end
                end
              else
                r = embedded ? 'embeds_one' : 'has_one'
              end
              if r
                v = r + ' :' + property_name + ', class_name: \'' + property_type.to_s + '\''
                reflect(type_model, (embedded ? 'embedded_in' : 'belongs_to')+ ' :' + model_name.split('::').last.underscore + ', class_name: \'' + schema['title'] + '\'')
              end
            end
            reflect(c,v) if v
          end
        end

        nested.each{ |n|  reflect(c, 'accepts_nested_attributes_for :' + n)}

        if r = schema['required']
          v = 'validates_presence_of :' + r.shift
          r.each{|p| v += ', :' + p}
          reflect(c, v)
        end

        validations.each{|v| reflect(c, v)}

        @@parsed_schemas << model_name

        @@has_many_to_bind.each do |property_type, a|
          if i = a.find_index {|x| x[0].eql?(model_name)}
            a = a.delete_at(i)
            puts (type_model = reflect_class(property_type)).to_s + '  Binding property ' + a[1]
            reflect(c, 'belongs_to :' + property_type.split('::').last.underscore)
            reflect(type_model, 'has_many :' + a[1] + ', class_name: \'' + model_name + '\'')
          end
        end
        return c
      end

      def reflect(c, code)
        puts c.to_s + '  ' + code
        c.class_eval(code) if code
      end
    end
  end
end
