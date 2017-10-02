module Setup
  class Converter < Translator
    include RailsAdmin::Models::Setup::ConverterAdmin

    transformation_type :Conversion

    build_in_data_type.with(:namespace, :name, :source_data_type, :target_data_type,
                            :discard_events, :style, :source_handler, :snippet, :source_exporter,
                            :target_importer, :discard_chained_records).referenced_by(:namespace, :name)

    build_in_data_type.and(properties: { mapping: { type: {} } })

    field :map_attributes, type: Hash, default: {}

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
      self.map_attributes = @mapping.attributes
    end

    def mapping_attributes=(attrs)
      @mapping = map_model.new(attrs)
      self.map_attributes = @mapping.attributes
    end

    def validates_mapping
      mapping.validate
      mapping.errors.full_messages
    end

    def map_model
      if target_data_type
        if @mongoff_model && @mongoff_model.data_type != target_data_type
          @mongoff_model = nil
        end
        @mongoff_model ||= MappingModel.for(data_type: target_data_type,
                                            cache: false,
                                            source_data_type: source_data_type)
      else
        @mongoff_model = nil
        Mongoff::Model.for(data_type: self.class.data_type,
                           schema: {},
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

    class MappingModel < Mongoff::Model

      def mapping_schema
        if @parent_map_model
          @parent_map_model.mapping_schema
        else
          @mapping_schema ||=
            begin
              sch = {
                type: 'object',
                properties: {
                  source: {
                    type: 'string'
                  },
                  transformation: {
                    referenced: true,
                    '$ref': {
                      namespace: 'Setup',
                      name: 'Translator'
                    },
                    filter: {
                      '$or':
                        [
                          # {
                          #   type: {
                          #     a: {
                          #       v: 'Export'
                          #     }
                          #   },
                          #   source_data_type: {
                          #     a: {
                          #       v: '_blank'
                          #     }
                          #   }
                          # },
                          {
                            type: {
                              a: {
                                v: 'Conversion'
                              }
                            },
                            source_data_type: {
                              a: {
                                v: '__source_data_type_id__'
                              }
                            },
                            target_data_type: {
                              a: {
                                v: '123'
                              }
                            }
                          }
                        ]
                    }
                  }
                }
              }.deep_stringify_keys
              if source_data_type
                enum = ["Source #{source_data_type.title}"]
                source_model = source_data_type.records_model
                source_model.properties.each do |property|
                  property_dt = source_model.property_model(property).data_type
                  enum << property unless property_dt == source_data_type
                end
                sch['properties']['source']['enum'] = enum
              end
              sch
            end
        end
      end

      def proto_schema
        to_map_schema(super)
      end

      def to_map_schema(sch)
        if sch['type'] == 'object' && (properties = sch['properties']).is_a?(Hash)
          new_properties = {}
          properties.each do |property, property_schema|
            ref, property_dt = check_referenced_schema(property_schema)
            if ref && property_dt
              description = data_type.merge_schema(property_schema)['description']
              description = "#{description}<br><strong>Define a transformation from #{source_data_type.custom_title} to #{property_dt.custom_title}</strong>"
              property_schema = mapping_schema.merge('description' => description)
            else
              property_schema = data_type.merge_schema(property_schema)
              unless property == '_id' && (property_schema['type'] || {}).is_a?(Hash) && property_schema['type'].blank?
                property_schema.reject! { |key, _| %w(title description edi).exclude?(key) }
                property_schema['type'] = 'string'
              end
            end
            new_properties[property] = property_schema
          end
          sch['properties'] = new_properties
        end
        sch
      end

      def data_type_records_model(data_type)
        if data_type.is_a?(Setup::JsonDataType)
          self.for(data_type: data_type, cache: false)
        else
          super
        end
      end

      def source_data_type
        @source_data_type ||= @parent_map_model && @parent_map_model.source_data_type
      end

      def for(options)
        options[:parent_map_model] ||= self
        super
      end

      protected

      def initialize(data_type, options = {})
        @parent_map_model = options.delete(:parent_map_model)
        @source_data_type = options.delete(:source_data_type)
        super
      end
    end
  end
end
