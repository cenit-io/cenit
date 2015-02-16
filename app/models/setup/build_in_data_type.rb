module Setup
  class BuildInDataType < BaseDataType

    attr_reader :model

    def initialize(model)
      @model = model
    end

    def schema
      @schema ||= build_schema
    end

    def find_data_type(ref)
      BuildInDataType.build_ins[ref]
    end

    def embedding(*fields)
      @embedding = fields.is_a?(Enumerable) ? fields : [fields]
    end

    def referenced_by(field_name)
      @referenced_by = field_name
      self
    end

    def and(to_merge)
      @to_merge = to_merge
      self
    end

    def with(*fields)
      if fields.present?
        raise Exception.new('Illegal argument') if fields.empty?
        fields = [fields] unless fields.is_a?(Enumerable)
        @with = fields.collect { |field| field.to_s }
      else
        @with = nil
      end
    end

    class << self

      def build_ins
        @build_ins ||= {}
      end

      def regist(model)
        model.define_singleton_method(:data_type) do
          BuildInDataType.build_ins[self.to_s]
        end
        model.include(Edi::Formatter)
        model.class_eval('def data_type
          self.class.data_type
        end')
        build_ins[model.to_s] = BuildInDataType.new(model)
      end
    end

    private

    EXCLUDED_FIELDS = %w{_id created_at updated_at version}
    EXCLUDED_RELATIONS = %w{account creator updater version}.collect { |str| str.to_sym }
    MONGOID_TYPE_MAP = {Array => 'array',
                        BigDecimal => 'integer',
                        Mongoid::Boolean => 'boolean',
                        Date => {'type' => 'string', 'format' => 'date'},
                        DateTime => {'type' => 'string', 'format' => 'date-time'},
                        Float => 'number',
                        Hash => 'object',
                        Integer => 'integer',
                        String => 'string',
                        Symbol => 'string',
                        Time => {'type' => 'string', 'format' => 'time'}}

    def build_schema
      schema = {'type' => 'object', 'properties' => properties = {}}
      schema[:referenced_by.to_s] = @referenced_by.to_s if @referenced_by
      (fields = model.fields).each do |field_name, field|
        properties[field_name] = json_schema_type(field.type) if !field.is_a?(Mongoid::Fields::ForeignKey) && ((@with && @with.include?(field_name)) || !(@with || EXCLUDED_FIELDS.include?(field_name)))
      end
      (relations = model.reflect_on_all_associations(:embeds_one,
                                                     :embeds_many,
                                                     :has_one,
                                                     :belongs_to,
                                                     :has_many,
                                                     :has_and_belongs_to_many)).each do |relation|
        if ((@with && @with.include?(relation.name)) || !(@with || EXCLUDED_RELATIONS.include?(relation.name)))
          property_schema = case relation.macro
                              when :embeds_one
                                {'$ref' => relation.klass.to_s}
                              when :embeds_many
                                {'type' => 'array', 'items' => {'$ref' => relation.klass.to_s}}
                              when :has_one
                                {'$ref' => relation.klass.to_s, 'referenced' => @embedding.nil? || !@embedding.include?(relation.name)}
                              when :belongs_to
                                {'$ref' => relation.klass.to_s, 'referenced' => @embedding.nil? || !@embedding.include?(relation.name)} unless relation.inverse_of.present?
                              when :has_many, :has_and_belongs_to_many
                                {'type' => 'array', 'items' => {'$ref' => relation.klass.to_s}, 'referenced' => @embedding.nil? || !@embedding.include?(relation.name)}
                            end
          properties[relation.name] = property_schema if property_schema
        end
      end
      schema = @to_merge.merge(schema) if @to_merge
      schema.to_json
    end

    def json_schema_type(mongoid_type)
      ((type = MONGOID_TYPE_MAP[mongoid_type]).is_a?(Hash)) ? type : {'type' => type}
    end
  end
end
