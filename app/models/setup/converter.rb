module Setup
  class Converter < Translator
    include RailsAdmin::Models::Setup::ConverterAdmin

    transformation_type :Conversion

    build_in_data_type.with(:namespace, :name, :source_data_type, :target_data_type,
                            :discard_events, :style, :source_handler, :snippet, :source_exporter,
                            :target_importer, :discard_chained_records, :map_attributes).referenced_by(:namespace, :name)

    build_in_data_type.and(properties: { mapping: { type: {}, edi: { discard: true } } })

    field :map_attributes, type: Hash, default: {}

    before_save do
      self.map_attributes = mapping.attributes
    end

    # TODO Remove when refactoring translators in style models
    def snippet_required?
      %w(chain mapping).exclude?(style)
    end

    def ready_to_save?
      super && (style != 'mapping' || mapping.present?)
    end

    def mapping
      if target_data_type
        @mapping ||= map_model.new(map_attributes)
      else
        @mapping = nil
      end
    end

    def do_map(source)
      locals = {}
      source_data_type.records_model.properties.each do |property|
        locals[property] = source.send(property)
      end
      json = mapping.to_json
      handlebars = Handlebars::Context.new
      json = handlebars.compile(json).call(locals)
      target_data_type.records_model.new_from_json(json)
    end

    def mapping=(data)
      unless data.is_a?(Hash)
        data =
          if data.is_a?(String)
            JSON.parse(data)
          else
            data.try(:to_json) || {}
          end
      end
      @mapping = map_model.new_from_json(data)
    end

    def mapping_attributes=(attrs)
      @mapping ||= map_model.new(attrs)
    end

    def validates_mapping
      mapping.validate
      mapping.errors.full_messages
    end

    def map_schema
      tdt_id = target_data_type && target_data_type.id.to_s
      unless @map_schema && @map_schema['target_data_type'] == tdt_id
        @map_schema =
          if tdt_id
            build_map_schema(target_data_type.records_model)
          else
            {}
          end
        @map_schema['target_data_type'] = tdt_id
      end
      @map_schema
    end

    def build_map_schema(model, models = Set.new)
      return {} if models.include?(model)
      data_type = model.data_type
      schema = { 'type' => 'object', 'properties' => properties = {} }
      model.properties_schemas.each do |property, property_schema|
        property_schema = data_type.merge_schema(property_schema)
        if (property_model = model.property_model(property)).modelable?
          unless property_schema['referenced']
            embedded_schema = build_map_schema(property_model, models)
            if property_schema['type'] == 'array'
              property_schema['items'] = embedded_schema
            else
              property_schema.merge!(embedded_schema)
            end
          end
        else
          unless property == '_id' && (property_schema['type'] || {}).is_a?(Hash) && property_schema['type'].blank?
            property_schema.reject! { |key, _| %w(title description edi).exclude?(key) }
            property_schema['type'] = 'string'
          end
        end
        properties[property] = property_schema
      end
      schema
    end

    def map_model
      if target_data_type
        @mongoff_model ||= Mongoff::Model.for(data_type: target_data_type,
                                              schema: map_schema,
                                              name: self.class.map_model_name,
                                              cache: false)
      else
        @mongoff_model = nil
        Mongoff::Model.for(data_type: self.class.data_type,
                           schema: map_schema,
                           name: "#{self.class.map_model_name}Default",
                           cache: false)
      end
    end

    def validates_configuration
      super
      if style == 'mapping'
        unless requires(:map_attributes)
          validates_mapping.each do |error|
            errors.add(:base, error)
          end
        end
      else
        rejects :map_attributes
      end
      errors.blank?
    end

    def association_for_mapping
      @mapping_association ||= MappingAssociation.new(self)
    end

    def reflect_on_association(name)
      if name == :mapping
        association_for_mapping
      else
        super
      end
    end

    class << self
      def map_model_name
        "#{Setup::Converter}::Map"
      end

      def stored_properties_on(record)
        non_mapping = super
        if record.style == 'mapping'
          non_mapping + ['mapping']
        else
          non_mapping
        end
      end

      def for_each_association(&block)
        super
        block.yield(name: :mapping, embedded: false)
      end
    end

    class MappingAssociation < Mongoff::Association

      attr_reader :mapper

      def initialize(mapper)
        super(mapper.class, :mapping, :embeds_one)
        @mapper = mapper
      end

      def klass
        mapper.map_model
      end
    end

    protected :build_map_schema
  end
end
