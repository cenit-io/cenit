require 'json-schema/schema/cenit_reader'
require 'json-schema/validators/mongoff'

module Mongoff
  class Model
    include Setup::InstanceAffectRelation
    include Setup::InstanceModelParser
    include MetadataAccess
    include Queryable

    EMPTY_SCHEMA = {}.freeze

    attr_reader :name
    attr_reader :parent

    def to_s
      parent ? "#{parent}::#{name}" : name
    end

    def schema_name
      to_s
    end

    def data_type
      @data_type_id.is_a?(Setup::Model) ? @data_type_id : Setup::Model.where(id: @data_type_id).first
    end

    def new
      record_class.new(self)
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
      if model_schema?(@schema = proto_schema)
        @schema = (Model[:base_schema] || {}).deep_merge(@schema)
      end unless @schema
      @schema
    end

    def model_schema?(schema)
      schema = schema['items'] if schema['type'] == 'array' && schema['items']
      schema = data_type.merge_schema(schema)
      schema['type'] == 'object' && !schema['properties'].nil?
    end

    def property_model?(property)
      property = property.to_s
      schema['type'] == 'object' && schema['properties'] && (property_schema = schema['properties'][property]) && model_schema?(property_schema)
    end

    def property_model(property)
      property = property.to_s
      model = nil
      if schema['type'] == 'object' && schema['properties'] && property_schema = schema['properties'][property]
        property_schema = property_schema['items'] if property_schema['type'] == 'array' && property_schema['items']
        model =
          if (ref = property_schema['$ref']) && property_dt = data_type.find_data_type(ref)
            property_dt.records_model
          else
            property_schema = data_type.merge_schema(property_schema)
            if property_schema['type'] == 'object' && property_schema['properties']
              Model.for(data_type: data_type, name: property.camelize, parent: self, schema: property_schema)
            else
              nil
            end
          end
      end
      model
    end

    def for_each_association(&block)
      properties_schemas.each do |property, schema|
        block.yield(name: property, embedded: !schema['referenced']) if property_model?(property)
      end
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
      all_collections_names.each { |name| Mongoid::Sessions.default[name.to_sym].drop }
    end

    def collection
      Mongoid::Sessions.default[collection_name]
    end

    def storage_size(scale = 1)
      data_type.all_data_type_storage_collections_names.inject(0) do |size, name|
        s = Mongoid::Sessions.default.command(collstats: name, scale: scale)['size'] rescue 0
        size + s
      end
    end

    def all
      find
    end

    def method_missing(symbol, *args)
      query_for(self, collection, symbol, *args) || super
    end

    def eql?(obj)
      if obj.is_a?(Mongoff::Model)
        data_type == obj.data_type && schema == obj.schema
      else
        super
      end
    end

    def submodel_of?(model)
      return true if self.eql?(model) || (@base_model && @base_model.submodel_of?(model))
      base_model =
        if base_data_type = data_type.find_data_type(JSON.parse(data_type.model_schema)['extends'])
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

    def attribute_key(field, field_metadata = {})
      if (field_metadata[:model] ||= property_model(field)) && (schema = (field_metadata[:schema] ||= property_schema(field)))['referenced']
        return ("#{field}_id" + ('s' if schema['type'] == 'array').to_s).to_sym
      end
      field
    end

    CONVERSION = {
      BSON::ObjectId => ->(value) { BSON::ObjectId.from_string(value.to_s) },
      BSON::Binary => ->(value) { BSON::Binary.new(value.to_s) },
      String => ->(value) { value.to_s },
      Integer => ->(value) { value.to_s.to_i },
      Float => ->(value) { value.to_s.to_f },
      Date => ->(value) { Date.parse(value.to_s) rescue nil },
      DateTime => ->(value) { DateTime.parse(value.to_s) rescue nil },
      Time => ->(value) { Time.parse(value.to_s) rescue nil },
      Hash => ->(value) { JSON.parse(value.to_s) rescue nil },
      Array => ->(value) { JSON.parse(value.to_s) rescue nil },
      nil => ->(value) { Cenit::Utility.json_object?(value) ? value : nil }
    }

    def mongo_value(value, field_or_schema)
      type =
        if !caching? || field_or_schema.is_a?(Hash)
          mongo_type_for(field_or_schema)
        else
          @mongo_types[field_or_schema] ||= mongo_type_for(field_or_schema)
        end
      if value.is_a?(type)
        value
      else
        convert(type, value)
      end
    end

    def convert(type, value)
      CONVERSION[type].call(value)
    end

    def fully_validate_against_schema(value, options = {})
      JSON::Validator.fully_validate(schema, value, options.merge(version: :mongoff,
                                                                  schema_reader: JSON::Schema::CenitReader.new(data_type),
                                                                  errors_as_objects: true))
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
        if !symbol.to_s.end_with?('=') && ((args.length == 0 && block_given?) || args.length == 1 && !block_given?)
          self[symbol] = block_given? ? yield : args[0]
        elsif args.length == 0 && !block_given?
          self[symbol]
        else
          super
        end
      end

      def for(options = {})
        model_name = options[:name]
        cache_model = (cache_models = Thread.current[:mongoff_models] ||= {})[model_name]
        unless data_type = (options[:data_type] || (cache_model && cache_model.data_type))
          raise Exception.new('name or data type required') unless model_name
          unless data_type = Setup::Model.for_name(model_name.split('::').first)
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

    protected

    def initialize(data_type, options = {})
      @data_type_id = (data_type.is_a?(Setup::BuildInDataType) || options[:cache]) ? data_type : data_type.id.to_s
      @name = options[:name] || data_type.data_type_name
      @parent = options[:parent]
      @persistable = (@schema = options[:schema]).nil?
      @modelable = options[:modelable]
      unless options[:observable].nil?
        @observable = options[:observable]
      end
      @mongo_types = {}
      @custom_properties = {}.with_indifferent_access
    end

    def caching?
      !@data_type_id.is_a?(String)
    end

    def proto_schema
      data_type.merged_schema(recursive: caching?)
    end
  end
end