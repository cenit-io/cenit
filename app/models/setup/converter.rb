module Setup
  class Converter < Translator
    include RailsAdmin::Models::Setup::ConverterAdmin
    include Setup::TranslationCommon::ClassMethods

    transformation_type :Conversion

    build_in_data_type.with(:namespace, :name, :source_data_type, :target_data_type,
                            :discard_events, :style, :source_handler, :snippet, :source_exporter,
                            :target_importer, :discard_chained_records).referenced_by(:namespace, :name)

    build_in_data_type.and(properties: { mapping: { type: {} } })

    field :map_attributes, type: Hash, default: {}

    def validates_configuration
      super
      if style == 'mapping'
        unless requires(:map_attributes)
          validates_mapping.each do |error|
            errors.add(:mapping, error)
          end
        end
      else
        rejects :map_attributes
      end
      errors.blank?
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
      plain_properties = []
      map_model.properties_schemas.each do |property, schema|
        plain_properties << property unless schema[MappingModel::SCHEMA_FLAG]
      end
      json = render_template(mapping.to_hash(only: plain_properties, include_id: false), source_data_type, source)
      target = target_data_type.records_model.new_from_json(json)
      map_model.for_each_association do |a|
        name = a[:name]
        schema = map_model.property_schema(name)
        next unless schema[MappingModel::SCHEMA_FLAG]
        sub_map = mapping[name]
        sub_map_source =
          if sub_map.source == '$'
            source
          else
            source.send(sub_map.source)
          end
        transformation = sub_map.transformation
        options = parse_options(sub_map.options)
        target_association = target_data_type.records_model.associations[name]
        target_model = target_association.klass
        sub_map_source_data_type =
          if sub_map.source == '$'
            source_data_type
          else
            source_data_type.records_model.property_model(sub_map.source).data_type
          end
        run_transformation(transformation, sub_map_source_data_type, sub_map_source, options) do |result, opts|
          unless (target_model.is_a?(Class) && result.is_a?(target_association.klass)) ||
            (result.is_a?(Mongoff::Record) && result.is_a?(target_model))
            opts = opts.merge(discard_events: true).with_indifferent_access
            if transformation.type == :Export && target_model.data_type.is_a?(Setup::FileDataType)
              opts[:contentType] ||= transformation.mime_type
              unless (file_extension = transformation.file_extension).nil? || opts[:filename].to_s.ends_with?(".#{file_extension}")
                opts[:filename] = "#{opts[:filename].to_s.presence || 'file'}.#{file_extension}"
              end
            end
            result = target_model.data_type.new_from(result.to_s, opts)
          end
          if target_association.many?
            target.send(name) << result
          else
            target.send("#{name}=", result)
          end
        end
      end
      target
    end

    def run_transformation(transformation, source_data_type, source, options)
      source = [source] unless source.is_a?(Enumerable)
      if (transformation.type == :Export && transformation.bulk_source) ||
        (transformation.type == :Conversion && transformation.source_handler)
        r = transformation.run(objects: source, options: options)
        yield r, options if block_given?
      else
        source.each do |obj|
          template = Handlebars::Context.new.compile(options.to_json)
          opts = render_template(template, source_data_type, obj)
          r = transformation.run(object: obj, options: opts)
          yield r, opts if block_given?
        end
      end
    end

    def render_template(template, data_type, record)
      locals = {}
      data_type.records_model.properties.each do |property|
        locals[property] = record.send(property)
      end
      unless template.is_a?(Handlebars::Template)
        template =
          if template.is_a?(Hash)
            template.to_json
          else
            template.to_s
          end
        template = Handlebars::Context.new.compile(template)
      end
      JSON.parse(template.call(locals))
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
      unless mapping.errors.present?
        map_model.for_each_association do |a|
          name = a[:name]
          schema = map_model.property_schema(name)
          next unless schema[MappingModel::SCHEMA_FLAG]
          sub_map = mapping[name]
          source_association = nil
          source_dt =
            if sub_map.source == '$'
              source_data_type
            else
              source_data_type &&
                (source_association = source_data_type.records_model.associations[sub_map.source]) &&
                (source_model = source_association.klass) &&
                source_model.data_type
            end
          transformation = sub_map.transformation
          sub_map.errors.add(:source, 'reference is invalid') unless source_dt
          if transformation
            sub_map.errors.add(:transformation, 'type is invalid') unless [:Export, :Conversion].include?(transformation.type)
          else
            sub_map.errors.add(:transformation, 'reference is invalid')
          end
          if sub_map.errors.blank?
            target_association = target_data_type.records_model.associations[name]
            if source_association && source_association.many? && !target_association.many? && !transformation.bulk_source
              sub_map.errors.add(:source, "is a many association and can not be mapped to #{target_data_type.custom_title} | #{schema['title'] || name.to_title} (which is not many) with the non bulk transformation #{transformation.custom_title}")
            end
            if (t_data_type = transformation.data_type).nil? || t_data_type == source_dt
              unless transformation.type == :Export
                sub_map_target_dt = target_data_type.records_model.property_model(name).data_type
                t_target_dt = transformation.target_data_type
                unless t_target_dt == sub_map_target_dt
                  sub_map.errors.add(:transformation, "target data type (#{t_target_dt ? t_target_dt.custom_title : 'nil'}) is invalid (#{sub_map_target_dt.custom_title} expected)")
                end
              end
            else
              sub_map.errors.add(:transformation, "data type (#{t_data_type ? t_data_type.custom_title : 'nil'}) and source data type (#{source_dt.custom_title}) mismatch")
            end
          end
          begin
            parse_options(sub_map.options)
          rescue Exception => ex
            sub_map.errors.add(:options, ex.message)
          end
          mapping.errors.add(name, 'is invalid') if sub_map.errors.present?
        end
      end
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
        block.yield(name: :mapping, embedded: false, many: false)
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

      SCHEMA_FLAG = self.to_s

      def mapping_schema
        if @parent_map_model
          @parent_map_model.mapping_schema
        else
          @mapping_schema ||=
            begin
              sch = {
                SCHEMA_FLAG.to_s => true,
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
                          {
                            type: {
                              a: {
                                v: 'Export'
                              }
                            },
                            source_data_type: {
                              a: {
                                v: '_blank'
                              }
                            }
                          },
                          {
                            type: {
                              a: {
                                v: 'Conversion'
                              }
                            }
                          }
                        ]
                    }
                  },
                  options: {
                    type: 'string'
                  }
                }
              }.deep_stringify_keys
              if source_data_type
                enum = ['$']
                enumNames = [source_data_type.custom_title]
                source_model = source_data_type.records_model
                source_model.properties.each do |property|
                  property_dt = source_model.property_model(property).data_type
                  unless property_dt == source_data_type
                    enum << property
                    enumNames << "#{source_data_type.custom_title} | #{(property_dt.schema['title'] || property.to_title)}"
                  end
                end
                sch['properties']['source']['enum'] = enum
                sch['properties']['source']['enumNames'] = enumNames
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
