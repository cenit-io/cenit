require 'edi/formater'
require 'xsd/core_ext'

module Setup
  class BuildInDataType
    include SchemaHandler
    include DataTypeParser

    attr_reader :model

    def namespace
      Setup.to_s
    end

    def title
      @title ||= model.to_s.to_title
    end

    def custom_title
      "#{Setup.to_s} | #{title}"
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
      if model < CrossOrigin::Document
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

    def referenced_by(*fields)
      unless fields.nil?
        fields = [fields] unless fields.is_a?(Enumerable)
        fields << :_id
      end
      store_fields(:@referenced_by, *fields)
    end

    def and(to_merge)
      @to_merge = (@to_merge || {}).merge(to_merge.deep_stringify_keys)
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
            model.class.include(Mongoid::CenitExtension)
            build_in = BuildInDataType.new(model)
            block.call(build_in) if block
            build_in
          end
      end
    end

    EXCLUDED_FIELDS = %w{_id created_at updated_at version}
    EXCLUDED_RELATIONS = %w{account creator updater}

    def method_missing(symbol, *args)
      if symbol.to_s.start_with?('get_')
        instance_variable_get(:"@#{symbol.to_s.from(4)}")
      else
        super
      end
    end

    private

    def store_fields(instance_variable, *fields)
      if fields
        raise Exception.new('Illegal argument') unless fields.present?
        fields = [fields] unless fields.is_a?(Enumerable)
        instance_variable_set(instance_variable, fields.flatten.collect(&:to_s).uniq.select(&:present?))
      else
        instance_variable_set(instance_variable, nil)
      end
      self
    end

    MONGOID_TYPE_MAP =
      {
        BSON::ObjectId => { type: 'string' },
        Array => { type: 'array' },
        BigDecimal => { type: 'integer' },
        Mongoid::Boolean => { type: 'boolean' },
        Date => { type: 'string', format: 'date' },
        DateTime => { type: 'string', format: 'date-time' },
        Float => { type: 'number' },
        Hash => { type: 'object' },
        Integer => { type: 'integer' },
        String => { type: 'string' },
        Symbol => { type: 'string' },
        Time => { type: 'string', format: 'time' },
        nil => {},
        Object => {}
      }.freeze

    def excluded?(name)
      name = name.to_s
      (@excluding && @excluding.include?(name)) || EXCLUDED_FIELDS.include?(name) || EXCLUDED_RELATIONS.include?(name)
    end

    def included?(name)
      [:@with, :@including, :@embedding, :@discarding].each { |v| return true if (v = instance_variable_get(v)) && v.include?(name) }
      !(@with || excluded?(name))
    end

    def build_schema
      @discarding ||= []
      schema = { type: 'object', properties: properties = { _id: { type: 'string' } } }
      schema[:referenced_by] = Cenit::Utility.stringfy(@referenced_by) if @referenced_by
      model.fields.each do |field_name, field|
        if !field.is_a?(Mongoid::Fields::ForeignKey) && included?(field_name.to_s)
          json_type = (properties[field_name] = json_schema_type(field.type))[:type]
          if @discarding.include?(field_name)
            (properties[field_name][:edi] ||= {})[:discard] = true
          end
          if json_type.nil? || json_type == 'object' || json_type == 'array'
            unless (mongoff_models = model.instance_variable_get(:@mongoff_models))
              model.instance_variable_set(:@mongoff_models, mongoff_models = {})
            end
            mongoff_models[field_name] = Mongoff::Model.for(data_type: self,
                                                            name: field_name.camelize,
                                                            parent: model,
                                                            schema: properties[field_name],
                                                            cache: false,
                                                            modelable: false,
                                                            root_schema: schema)
          end
        end
      end
      model.reflect_on_all_associations(:embeds_one,
                                        :embeds_many,
                                        :has_one,
                                        :belongs_to,
                                        :has_many,
                                        :has_and_belongs_to_many).each do |relation|
        if included?((relation_name = relation.name.to_s))
          property_schema =
            case relation.macro
            when :embeds_one
              {
                '$ref': relation.klass.to_s
              }
            when :embeds_many
              {
                type: 'array',
                items: { '$ref': relation.klass.to_s }
              }
            when :has_one
              {
                '$ref': relation.klass.to_s,
                referenced: true,
                export_embedded: (@embedding && @embedding.include?(relation_name)).to_b
              }
            when :belongs_to
              ((@including && @including.include?(relation_name.to_s)) || relation.inverse_of.nil?) &&
                {
                  '$ref': relation.klass.to_s,
                  referenced: true,
                  export_embedded: (@embedding && @embedding.include?(relation_name)).to_b
                }
            when :has_many, :has_and_belongs_to_many
              {
                type: 'array',
                items: { '$ref': relation.klass.to_s },
                referenced: true,
                export_embedded: (@embedding && @embedding.include?(relation_name)).to_b
              }
            end
          if property_schema
            if @discarding.include?(relation_name.to_s)
              (property_schema[:edi] ||= {})[:discard] = true
            end
            properties[relation_name] = property_schema
          end
        end
      end
      schema[:protected] = @protecting if @protecting.present?
      schema = schema.deep_reverse_merge(@to_merge) if @to_merge
      schema.deep_stringify_keys
    end

    def json_schema_type(mongoid_type)
      MONGOID_TYPE_MAP[mongoid_type].dup
    end

  end
end
