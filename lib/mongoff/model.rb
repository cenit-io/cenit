
module Mongoff
  class Model
    include Setup::InstanceModelParser
    include MetadataAccess
    include PrettyErrors
    include ThreadAware

    EMPTY_SCHEMA = {}.freeze

    attr_reader :name
    attr_reader :parent

    def to_s
      parent ? "#{parent}::#{name}" : name
    end

    def schema_name
      to_s
    end

    def data_type_id
      case @data_type_id
      when Setup::DataType
        @data_type_id.id
      when Setup::BuildInDataType
        @data_type_id.db_data_type.id
      else
        @data_type_id
      end
    end

    def data_type
      if @data_type_id.is_a?(Setup::DataType) || @data_type_id.is_a?(Setup::BuildInDataType)
        @data_type_id
      else
        Setup::DataType.where(id: @data_type_id).first
      end
    end

    def new(attributes = {})
      record_class.new(self, attributes)
    end

    def record_class
      Record
    end

    def observable?
      @observable.nil? ? reflectable? : @observable && true
    end

    def reflectable?
      persistable?
    end

    def type_polymorphic?
      reflectable?
    end

    def persistable?
      @persistable
    end

    def modelable?
      if @modelable.nil?
        @modelable = model_schema?(schema)
      else
        @modelable
      end
    end

    def schema
      unless @schema
        if model_schema?(@schema = proto_schema)
          @schema = @schema.deep_reverse_merge(Model[:base_schema] || {})
        end
      end
      @schema
    end

    def model_schema?(schema)
      schema = schema['items'] if schema.is_a?(Hash) && schema['type'] == 'array' && schema['items']
      schema = data_type.merge_schema(schema)
      schema.is_a?(Hash) && schema['type'] == 'object' && !schema['properties'].nil?
    end

    def property_model?(property)
      property = property.to_s
      schema['type'] == 'object' && schema['properties'] && (property_schema = schema['properties'][property]) && model_schema?(property_schema)
    end

    def properties_models
      @properties_models ||= {}
    end

    def property_model(property)
      property = property.to_s
      model = nil
      if schema.is_a?(Hash) && schema['type'] == 'object' && schema['properties'].is_a?(Hash) && (property_schema = schema['properties'][property])
        if properties_models.key?(property)
          model = properties_models[property]
        else
          ref, property_dt = check_referenced_schema(property_schema)
          model =
            if ref
              if property_dt
                data_type_records_model(property_dt)
              else
                fail "Data type reference not found: #{ref}"
              end
            else
              property_schema = data_type.merge_schema(property_schema)
              records_schema =
                if property_schema['type'] == 'array' && property_schema.has_key?('items')
                  property_schema['items']
                else
                  property_schema
                end
              Model.for(data_type: data_type, name: property.camelize, parent: self, schema: records_schema)
            end
          schema['properties'][property] = property_schema
          properties_models[property] = model
        end
      end
      model
    end

    def stored_properties_on(record)
      properties = Set.new
      record.document.each_key do |field|
        if property?(field)
          properties << field.to_s
        elsif (property = property_for_attribute(field.to_s))
          properties << property.to_s
        elsif data_type.additional_properties?
          properties << field.to_s
        end
      end
      record.fields.each_key { |field| properties << field.to_s }
      properties
    end

    def associations
      unless @associations
        @associations = {}.with_indifferent_access
        properties_schemas.each do |property, property_schema|
          if model.model_schema?(property_schema)
            macro =
              if property_schema['type'] == 'array'
                property_schema['referenced'] ? :has_and_belongs_to_many : :embeds_many
              else
                property_schema['referenced'] ? :belongs_to : :embeds_one
              end
            @associations[property.to_sym] = Mongoff::Association.new(self, property, macro)
          end
        end
      end
      @associations
    end

    def get_associations
      associations
    end

    def reflect_on_all_associations(*macros)
      associations.values.select { |a| macros.include?(a.macro) }
    end

    def reflect_on_association(name)
      relations[name.to_sym]
    end

    def for_each_association(&block)
      properties_schemas.each do |property, schema|
        block.yield(name: property, embedded: !schema['referenced'], many: schema['type'] == 'array') if property_model?(property)
      end
    end

    def hereditary?
      data_type.subtype?
    end

    def all_collections_names
      persistable? ? data_type.all_data_type_collections_names : [:empty_collection]
    end

    def collection_name
      persistable? ? data_type.data_type_collection_name.to_sym : :empty_collection
    end

    def count
      persistable? ? collection.find.count : 0
    end

    def delete_all
      all_collections_names.each { |name| mongo_client[name.to_sym].drop }
    end

    def collection
      mongo_client[collection_name]
    end

    def mongo_client
      Mongoid.default_client
    end

    def storage_size(scale = 1)
      subtype_count = data_type.subtype? && data_type.count
      data_type.all_data_type_storage_collections_names.inject(0) do |size, name|
        s =
          begin
            stats = mongo_client.command(collstats: name.to_s, scale: scale).first
            if subtype_count
              subtype_count + stats['avgObjSize']
            else
              stats['size']
            end
          rescue
            0
          end
        size + s
      end
    end

    def unscoped
      all
    end

    def method_missing(symbol, *args, &block)
      @criteria ||= Mongoff::Criteria.new(self)
      if @criteria.respond_to?(symbol)
        @criteria.send(symbol, *args, &block)
      else
        super
      end
    ensure
      @criteria = nil
    end

    def respond_to?(*args)
      super || ((@criteria = Mongoff::Criteria.new(self)) && @criteria.respond_to?(args[0]))
    end

    def eql?(obj)
      if obj.is_a?(Mongoff::Model)
        to_s == obj.to_s
      else
        super
      end
    end

    def submodel_of?(model)
      return true if eql?(model) || (@base_model && @base_model.submodel_of?(model))
      base_model =
        if (base_data_type = data_type.find_data_type(data_type.schema['extends']))
          Model.for(data_type: base_data_type, cache: caching?)
        else
          nil
        end
      if base_model
        @base_model = base_model if caching?
        base_model.submodel_of?(model)
      else
        false
      end
    end

    def <=(model)
      submodel_of?(model)
    end

    def attribute_key(field, field_metadata = {})
      field_metadata[:model] ||= property_model(field)
      model = field_metadata[:model]
      if model&.persistable? && (schema = (field_metadata[:schema] ||= property_schema(field)))['referenced']
        ((schema['type'] == 'array') ? field.to_s.singularize + '_ids' : "#{field}_id").to_sym
      else
        field.to_s == 'id' ? :_id : field.to_sym
      end
    end

    def property_for_attribute(name)
      if property?(name)
        name
      else
        match = name.to_s.match(/\A(.+)(_id(s)?)\Z/)
        name = match && "#{match[1]}#{match[3]}"
        if property?(name)
          name
        else
          nil
        end
      end
    end

    def to_string(value)
      case value
      when Hash, Array
        value.to_json
      else
        value.to_s
      end
    end

    CONVERSION = {

      BSON::ObjectId => ->(value) do
        if (id = value.try(:id)).is_a?(BSON::ObjectId)
          id
        else
          value = value.to_s
          if (match = value.match(/\A\$oid#(.*\Z)/))
            value = match[1]
          end
          BSON::ObjectId.from_string(value)
        end
      end,

      BSON::Binary => ->(value) { BSON::Binary.new(value.to_s) },
      Boolean => ->(value) { value.to_s.to_b },

      String => ->(value) do
        case value
        when Array, Hash
          value.to_json
        else
          value.to_s
        end
      end,

      Integer => ->(value) { value.to_s.to_i },
      Float => ->(value) { value.to_s.to_f },
      Date => ->(value) { DateTime.parse(value.to_s) },
      DateTime => ->(value) { DateTime.parse(value.to_s) },
      Time => ->(value) { Time.parse(value.to_s) },

      Hash => ->(value) do
        unless value.is_a?(Hash) || (value = JSON.parse(value.to_s)).is_a?(Hash)
          fail 'Array JSON not a Hash'
        end
        value
      end,

      Array => ->(value) do
        unless value.is_a?(Array) || (value = JSON.parse(value.to_s)).is_a?(Array)
          fail 'Hash JSON not an Array'
        end
        value
      end,

      NilClass => ->(value) do
        if Cenit::Utility.json_object?(value)
          value
        else
          fail 'Not a JSON value'
        end
      end
    }

    def mongo_value(value, field, schema = nil, &success_block)
      field = '_id' if field.to_s == 'id'
      types =
        if !caching? || schema
          mongo_type_for(field, schema)
        else
          @mongo_types[field] ||= mongo_type_for(field, schema)
        end
      success_value = nil
      success_type = nil
      conversion_value = nil
      conversion_type = nil
      types.each do |type|
        break if success_type
        if value.is_a?(type)
          success_value = value
          success_type = type
        elsif !conversion_type
          begin
            conversion_value = CONVERSION[type].call(value)
            conversion_type = type
          rescue Exception
          end
        end
      end
      if !success_type && conversion_type
        success_value = conversion_value
        success_type = conversion_type
      end
      if success_type && success_block
        args =
          case success_block.arity
          when 0
            []
          when 1
            [success_value]
          else
            [success_value, success_type]
          end
        success_block.call(*args)
      end
      success_value
    end

    class << self

      def options
        @options ||=
          {
            before_save: ->(_) {},
            after_save: ->(_) {}
          }
      end

      def [](option)
        options[option]
      end

      def []=(option, value)
        validate_option!(option, value)
        options[option] = value
      end

      def validate_option!(option, value)
        unless case option
               when :before_save, :after_save
                 value.is_a?(Proc)
               else
                 true
               end
          raise Exception.new("Invalid value #{value} for option #{option}")
        end
      end

      def config(&block)
        class_eval(&block) if block
      end

      def method_missing(symbol, *args)
        if !symbol.to_s.end_with?('=') && ((args.length.zero? && block_given?) || args.length == 1 && !block_given?)
          self[symbol] = block_given? ? yield : args[0]
        elsif args.length.zero? && !block_given?
          self[symbol]
        else
          super
        end
      end

      def for(options)
        model_name = options[:name]
        cache_model = (cache_models = current_thread_cache)[model_name]
        unless (data_type = (options[:data_type] || (cache_model && cache_model.data_type)))
          raise Exception.new('name or data type required') unless model_name
          unless (data_type = Setup::DataType.for_name(model_name.split('::').first))
            raise Exception.new("unknown data type for #{model_name}")
          end
        end
        options[:cache] = true if options[:cache].nil?
        return new(data_type, options) unless options[:cache]
        unless cache_model
          cache_model = new(data_type, options)
          cache_models[cache_model.to_s] = cache_model
        end
        cache_model
      end
    end

    def labeled?
      schema.key?('label')
    end

    def label_template
      if @label_template.nil? && (template = schema['label'])
        begin
          @label_template = Liquid::Template.parse(template)
        rescue Exception => ex
          return ex.message
        end
      end
      @label_template
    end

    def label(context = nil)
      if parent
        schema['title'] || to_s.split('::').last
      else
        case context
        when nil
          data_type.title
        when :breadcrumb
          data_type.custom_title('/')
        else
          data_type.custom_title
        end
      end
    end

    def for(options)
      self.class.for(options)
    end

    def model_name
      @model_name ||= ActiveModel::Name.new(nil, nil, name)
    end

    def human_attribute_name(attribute, _ = {})
      attribute.to_s.titleize
    end

    def method_defined?(*args)
      property?(args[0])
    end

    def relations
      associations
    end

    protected

    def initialize(data_type, options = {})
      @data_type_id =
        if data_type.is_a?(Setup::BuildInDataType) || options[:cache] || !data_type.persisted?
          data_type
        else
          data_type.id.to_s
        end
      @name = options[:name] || data_type.data_type_name
      @parent = options[:parent]
      unless (@persistable = (@schema = options[:schema]).nil?)
        @schema = data_type.merge_schema(@schema, root_schema: options[:root_schema])
      end
      @modelable = options[:modelable]
      unless options[:observable].nil?
        @observable = options[:observable]
      end
      @mongo_types = {}
    end

    def caching?
      !@data_type_id.is_a?(String) #TODO Check this, not a BSON::Id ?
    end

    def proto_schema
      sch = data_type.merged_schema || {}
      if (properties = sch['properties'])
        sch['properties'] = data_type.merge_schema(properties)
      end
      sch
    rescue Exception => ex
      {
        title: 'Error',
        description: "The schema data type of this model has errors: #{ex.message}"
      }.stringify_keys
    end

    def data_type_records_model(data_type)
      data_type.records_model
    end

    def check_referenced_schema(schema, check_for_array = true)
      if schema.is_a?(Hash) && (schema = schema.reject { |key, _| %w(types contextual_params data filter group xml unique title description edi format example enum readOnly default visible referenced_by maxProperties minProperties auto export_embedded exclusive).include?(key) })
        property_dt = nil
        ns = data_type.namespace
        if (ref = schema['$ref']).is_a?(Array)
          ref = nil
        elsif ref.is_a?(Hash)
          (ns = ref['namespace'].to_s)
          ref = ref['name']
        end
        ((ref.is_a?(String) && (schema.size == 1 || (schema.size == 2 && schema.has_key?('referenced')))) ||
          (schema['type'] == 'array' && (items = schema['items']) &&
            (schema.size == 2 || (schema.size == 3 && schema.has_key?('referenced'))) &&
            (items = items.reject { |key, _| %w(title description edi referenced_by).include?(key) }) &&
            items.size == 1 &&
            ((ref = items['$ref']).is_a?(String) ||
              (ref.is_a?(Hash) && (ns = ref['namespace'].to_s) && (ref = ref['name']).is_a?(String))))) &&
          (property_dt = data_type.find_data_type(ref, ns))
        [ref, property_dt]
      else
        [nil, nil]
      end
    end
  end
end
