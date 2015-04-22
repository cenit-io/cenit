module Mongoff
  class Model
    include Setup::InstanceAffectRelation

    EMPTY_SCHEMA = {}.freeze

    attr_reader :name
    attr_reader :parent

    def initialize(data_type, name = nil, parent = nil, schema = nil)
      @data_type_id = data_type.is_a?(Setup::BuildInDataType) ? data_type : data_type.id.to_s
      @name = name || data_type.data_type_name
      @parent = parent
      @persistable = (@schema = schema).nil?
    end

    def to_s
      parent ? "#{parent}::#{name}" : name
    end

    def schema_name
      to_s
    end

    def data_type
      @data_type_id.is_a?(Setup::BuildInDataType) ? @data_type_id : Setup::Model.where(id: @data_type_id).first
    end

    def new
      Record.new(self)
    end

    def persistable?
      @persistable
    end

    def schema
      @schema ||= data_type.merged_schema
    end

    def property_model(property)
      #TODO Create a model space to optimize memory usage
      model = nil
      if schema['type'] == 'object' && schema['properties'] && property_schema = schema['properties'][property.to_s]
        property_schema = property_schema['items'] if property_schema['type'] == 'array' && property_schema['items']
        model =
          if (ref = property_schema['$ref']) && property_dt = data_type.find_data_type(ref)
            Model.new(property_dt, nil, self)
          else
            Model.new(data_type, property.camelize, self, property_schema)
          end
      end
      model || Model.new(data_type, property.camelize, self, EMPTY_SCHEMA)
    end

    def for_each_association(&block)
      #TODO ALL
    end

    def all_collections_names
      persistable? ? data_type.all_data_type_collections_names : [:empty_collection]
    end

    def collection_name
      persistable? ? data_type.data_type_collection_name.to_sym : :empty_collection
    end

    def count
      persistable? ? Mongoid::Sessions.default[collection_name].find.count : 0
    end

    def delete_all
      all_collections_names.each { |name| Mongoid::Sessions.default[name.to_sym].drop }
    end

    def storage_size(scale = 1)
      all_collections_names.inject(0) do |size, name|
        s = Mongoid::Sessions.default.command(collstats: name, scale: scale)['size'] rescue 0
        size + s
      end
    end

    def method_missing(symbol, *args)
      if (query = Mongoid::Sessions.default[collection_name].try(symbol, *args)).is_a?(Moped::Query)
        Criteria.new(self, query)
      else
        super
      end
    end

    def eql?(obj)
      if obj.is_a?(Mongoff::Model)
        data_type == obj.data_type && schema == obj.schema
      else
        super
      end
    end
  end
end