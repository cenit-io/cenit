require 'edi/formater'
require 'xsd/core_ext'

module Setup
  class BuildInDataType
    include SchemaHandler
    include DataTypeParser

    attr_reader :model

    def request_db_data_type
      RequestStore.store["[cenit]#{self}.db_data_type".to_sym] ||= db_data_type
    end

    def db_data_type
      namespace = model.to_s.split('::')
      name = namespace.pop
      namespace = namespace.join('::')
      Setup::CenitDataType.find_or_create_by(namespace: namespace, name: name)
    end

    def namespace
      Setup.to_s
    end

    def title
      @title ||= model.to_s.split('::').last.to_title
    end

    def custom_title(separator = '|')
      model.to_s.split('::').collect(&:to_title).join(" #{separator} ")
    end

    def name
      @name ||= model.model_name.to_s
    end

    def data_type_name
      model.to_s
    end

    def records_methods
      []
    end

    def data_type_methods
      []
    end

    def before_save_callbacks
      []
    end

    def after_save_callbacks
      []
    end

    def count
      model.count
    end

    def initialize(model)
      @model = model
    end

    def subtype?
      model.superclass.include?(Mongoid::Document)
    end

    def records_model
      model
    end

    def slug
      model.to_s.split('::').last.underscore
    end

    def id
      model.to_s
    end

    def all_data_type_storage_collections_names
      if model < CrossOrigin::CenitDocument
        origins = model.origins.select { |origin| Setup::Crossing.authorized_crossing_origins.include?(origin) }
        origins.collect do |origin|
          if origin == :default
            model.collection_name
          else
            CrossOrigin[origin].collection_name_for(model)
          end
        end
      else
        [model.collection_name]
      end
    end

    def schema
      @schema ||= build_schema
    end

    def find_data_type(ref, ns = namespace)
      BuildInDataType.build_ins[ref] ||
        Setup::DataType.find_data_type(ref, ns)
    end

    def protecting?(field)
      (@protecting || []).include?(field.to_s)
    end

    def protecting(*fields)
      store_fields(:@protecting, *fields)
    end

    def embedding(*fields)
      store_fields(:@embedding, *fields)
    end

    def exclusive_referencing(*fields)
      store_fields(:@exclusive_referencing, *fields)
    end

    def referenced_by(*fields)
      unless fields.nil?
        fields = [fields] unless fields.is_a?(Enumerable)
        fields << :_id
      end
      store_fields(:@referenced_by, *fields)
    end

    def and(to_merge)
      if to_merge
        @to_merge = (@to_merge || {}).array_hash_merge(to_merge.deep_stringify_keys)
      end
      self
    end

    def with(*fields)
      store_fields(:@with, *fields)
    end

    def including(*fields)
      store_fields(:@including, fields, @including)
    end

    def discarding(*fields)
      store_fields(:@discarding, *fields, @discarding)
    end

    def excluding(*fields)
      store_fields(:@excluding, *fields, @excluding)
    end

    class << self

      def [](ref)
        build_ins[ref.to_s]
      end

      def build_ins
        @build_ins ||= {}
      end

      def each(&block)
        build_ins.values.each(&block)
      end

      def regist(model, &block)
        build_ins[model.to_s] ||=
          begin
            model.include(Setup::OrmModelAware)
            model.include(Setup::SchemaModelAware)
            model.include(Edi::Formatter)
            model.include(Edi::Filler)
            model.include(EventLookup)
            model.class.include(Mongoid::CenitExtension)
            build_in = BuildInDataType.new(model)
            block.call(build_in) if block
            build_in
          end
      end
    end

    def ns_slug
      Setup.to_s.underscore
    end

    EXCLUDED_FIELDS = %w(_id created_at updated_at version)
    EXCLUDED_RELATIONS = %w(account creator updater)

    def respond_to?(*args)
      args[0].to_s.start_with?('get_') || super
    end

    def method_missing(symbol, *args)
      if symbol.to_s.start_with?('get_')
        instance_variable_get(:"@#{symbol.to_s.from(4)}")
      else
        super
      end
    end

    def json_schema_type(mongoid_type)
      SCHEMA_TYPE_MAP[mongoid_type].dup
    end

    private

    def store_fields(instance_variable, *fields)
      if fields
        fail 'Illegal argument' unless fields.present?
        fields = [fields] unless fields.is_a?(Enumerable)
        instance_variable_set(instance_variable, fields.flatten.collect(&:to_s).uniq.select(&:present?))
      else
        instance_variable_set(instance_variable, nil)
      end
      self
    end

    SCHEMA_TYPE_MAP =
      {
        BSON::ObjectId => { 'type' => 'string' },
        Hash => { 'type' => 'object' },
        Array => { 'type' => 'array' },
        Integer => { 'type' => 'integer' },
        BigDecimal => { 'type' => 'integer' },
        Float => { 'type' => 'number' },
        Numeric => { 'type' => 'number' },
        Mongoid::Boolean => { 'type' => 'boolean' },
        TrueClass => { 'type' => 'boolean' },
        FalseClass => { 'type' => 'boolean' },
        Time => { 'type' => 'string', 'format' => 'time' },
        DateTime => { 'type' => 'string', 'format' => 'date-time' },
        Date => { 'type' => 'string', 'format' => 'date' },
        String => { 'type' => 'string' },
        Symbol => { 'type' => 'string' },
        nil => {},
        Object => {},
        Module => { 'type' => 'string' },
        Class => { 'type' => 'string' }
      }.freeze

    def excluded?(name)
      name = name.to_s
      (@excluding && @excluding.include?(name)) || EXCLUDED_FIELDS.include?(name) || EXCLUDED_RELATIONS.include?(name)
    end

    def included?(name)
      [:@with, :@including, :@embedding, :@discarding].any? do |v|
        (v = instance_variable_get(v)) && v.include?(name)
      end || !(@with || excluded?(name))
    end

    def build_schema
      @discarding ||= []
      schema = Mongoff::Model.base_schema.deep_merge('properties' => { 'id' => {} })
      properties = schema['properties']
      if model < ClassHierarchyAware
        if model.abstract?
          schema['abstract'] = true
          schema['descendants'] = (model.class_hierarchy - [model]).map do |sub_model|
            data_type = sub_model.data_type
            {
              id: data_type.id.to_s,
              namespace: data_type.namespace,
              name: data_type.name,
              abstract: sub_model.abstract?
            }.stringify_keys
          end
        end
      else
        properties.delete('_type')
      end
      schema[:referenced_by.to_s] = Cenit::Utility.stringfy(@referenced_by) if @referenced_by
      model.fields.each do |field_name, field|
        next unless !field.is_a?(Mongoid::Fields::ForeignKey) && included?(field_name.to_s)
        json_type = (properties[field_name] = json_schema_type(field.type))['type']
        if @discarding.include?(field_name)
          (properties[field_name]['edi'] ||= {})['discard'] = true
        end
        next unless json_type.nil? || json_type == 'object' || json_type == 'array'
        unless (mongoff_models = model.instance_variable_get(:@mongoff_models))
          model.instance_variable_set(:@mongoff_models, mongoff_models = {})
        end
        mongoff_models[field_name] = Mongoff::Model.for(
          data_type: self,
          name: field_name.camelize,
          parent: model,
          schema: properties[field_name],
          cache: false,
          modelable: false,
          root_schema: schema)
      end
      model.reflect_on_all_associations(:embeds_one,
                                        :embeds_many,
                                        :has_one,
                                        :belongs_to,
                                        :has_many,
                                        :has_and_belongs_to_many).each do |relation|
        next unless included?((relation_name = relation.name.to_s))
        property_schema =
          case relation.macro
          when :embeds_one
            {
              '$ref': build_ref(relation.klass)
            }
          when :embeds_many
            {
              type: 'array',
              items: {
                '$ref': build_ref(relation.klass)
              }
            }
          when :has_one
            {
              '$ref': build_ref(relation.klass),
              referenced: true,
              exclusive: (@exclusive_referencing && @exclusive_referencing.include?(relation_name)).to_b,
              export_embedded: (@embedding && @embedding.include?(relation_name)).to_b
            }
          when :belongs_to
            if (@including && @including.include?(relation_name.to_s)) || relation.inverse_of.nil?
              {
                '$ref': build_ref(relation.klass),
                referenced: true,
                exclusive: (@exclusive_referencing && @exclusive_referencing.include?(relation_name)).to_b,
                export_embedded: (@embedding && @embedding.include?(relation_name)).to_b
              }
            end
          when :has_many, :has_and_belongs_to_many
            {
              type: 'array',
              items: {
                '$ref': build_ref(relation.klass)
              },
              referenced: true,
              exclusive: (@exclusive_referencing && @exclusive_referencing.include?(relation_name)).to_b,
              export_embedded: (@embedding && @embedding.include?(relation_name)).to_b
            }
          end
        next unless property_schema
        property_schema.deep_stringify_keys!
        if @discarding.include?(relation_name.to_s)
          (property_schema['edi'] ||= {})['discard'] = true
        end
        properties[relation_name] = property_schema
      end
      schema['protected'] = @protecting if @protecting.present?
      schema = schema.deep_reverse_merge(@to_merge) if @to_merge
      schema
    end

    def build_ref(klass)
      tokens = klass.to_s.split('::')
      { 'name' => tokens.pop, 'namespace' => tokens.join('::') }
    end

  end
end
