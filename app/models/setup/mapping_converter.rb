module Setup
  class MappingConverter < ConverterTransformation
    include WithSourceOptions
    include Setup::TranslationCommon::ClassMethods
    include RailsAdmin::Models::Setup::MappingConverterAdmin

    build_in_data_type.and(properties: { mapping: { type: {} } }).excluding(:map_attributes).referenced_by(:namespace, :name)

    field :map_attributes, type: Hash, default: {}

    validates_presence_of :target_data_type, :map_attributes

    def execute(options)
      options[:target] = do_map(options[:source])
    end

    def write_attribute(name, value)
      if name.to_s == 'map_attributes'
        value.delete('_type')
        value.delete(:_type)
        value.each do |k, v|
          if v.present? && map_model.property?(k)
            if map_model.associations[k]
              if v.is_a?(Hash)
                v.delete_if { |sub_k, sub_v| %w(source transformation_id options).exclude?(sub_k.to_s) || !(sub_v.is_a?(String) || sub_v.is_a?(BSON::ObjectId)) || sub_v.blank? }
                value.delete(k) if v.empty?
              else
                value.delete(k)
              end
            else
              case map_model.property_schema(k)['type']
              when 'object'
                value.delete(k) unless v.is_a?(Hash)
              when 'array'
                value.delete(k) unless v.is_a?(Array)
              else
                value.delete(k) unless v.is_a?(String)
              end
            end
          else
            value.delete(k)
          end
        end
      end
      super
    end

    def ready_to_save?
      mapping.present?
    end

    def mapping(options = {})
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
      json = render_template(mapping.to_hash(only: plain_properties), source_data_type, source)
      target = target_data_type.records_model.new_from_json(json)
      map_model.for_each_association do |a|
        name = a[:name]
        schema = map_model.property_schema(name)
        next unless schema[MappingModel::SCHEMA_FLAG]
        sub_map = mapping[name]
        next unless sub_map
        sub_map_source =
          if sub_map.source == '$'
            source
          else
            source.send(sub_map.source)
          end
        next unless sub_map_source
        transformation = sub_map.transformation
        options = parse_options(sub_map.options)
        target_association = target_data_type.records_model.associations[name]
        target_model = target_association && target_association.klass
        sub_map_source_data_type =
          if sub_map.source == '$'
            source_data_type
          else
            source_data_type.records_model.property_model(sub_map.source).data_type
          end
        run_transformation(transformation, sub_map_source_data_type, sub_map_source, options) do |result, opts|
          unless target_model.nil? || (target_model.is_a?(Class) && result.is_a?(target_association.klass)) ||
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
          if target_association && target_association.many?
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
      if (transformation.type == :Export && transformation.try(:bulk_source)) ||
        (transformation.type == :Conversion && transformation.try(:source_handler)) #TODO After remove legacy translators check try(:bulk_source) and try(:source_handler)
        r = transformation.run(source_data_type: source_data_type, objects: source, save_result: false, options: options)
        yield r, options if block_given?
      else
        source.each do |obj|
          template = Liquid::Template.parse(options.to_json)
          opts = render_template(template, source_data_type, obj)
          r = transformation.run(source_data_type: source_data_type, object: obj, save_result: false, options: opts)
          yield r, opts if block_given?
        end
      end
    end

    def render_template(template, data_type, record)
      locals = {}
      data_type.records_model.properties.each do |property|
        locals[property] = record.send(property)
      end
      unless template.is_a?(Liquid::Template)
        template =
          if template.is_a?(Hash)
            template.to_json
          else
            template.to_s
          end
        template = Liquid::Template.parse(template)
      end
      JSON.parse(template.render(locals))
    end

    def set_relation(name, relation)
      r = super
      if @lazy_mapping && source_data_type && target_data_type
        self.mapping = @lazy_mapping
      end
      r
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
      if source_data_type && target_data_type
        @mapping = map_model.new_from_json(data)
        if @mapping.is_a?(Hash)
          self.map_attributes = @mapping
          @mapping = nil
        else
          self.map_attributes = @mapping.attributes
        end
        @lazy_mapping = nil
      else
        @lazy_mapping = data
      end
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
          if target_data_type.is_a?(Setup::FileDataType) && name.to_s != 'data'
            mapping.errors.add(:base, "Defines a non valid association #{name}")
            next
          end
          schema = map_model.property_schema(name)
          next unless schema[MappingModel::SCHEMA_FLAG]
          sub_map = mapping[name]
          next unless sub_map
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
            t_types = [:Export]
            t_types << :Conversion unless target_data_type.is_a?(Setup::FileDataType)
            sub_map.errors.add(:transformation, 'type is invalid') unless t_types.include?(transformation.type)
          else
            sub_map.errors.add(:transformation, 'reference is invalid')
          end
          if sub_map.errors.blank?
            target_association = target_data_type.records_model.associations[name]
            if source_association && source_association.many? &&
              (target_association.nil? || !target_association.many?) && # target_association is nil for file mappings
              !transformation.try(:bulk_source)
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
      if source_data_type && target_data_type
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

    def share_hash(options = {})
      hash = super
      if (mapping_id = self.mapping.id).present? && (mapping = hash['mapping'])
        hash['mapping'] = { 'id' => mapping_id }.merge(mapping)
      end
      hash
    end

    class << self

      def map_model_name
        "#{self}::Map"
      end

      def stored_properties_on(record)
        super + ['mapping']
      end

      def for_each_association(&block)
        super
        block.yield(name: :mapping, embedded: true, many: false)
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

      def mapping_schema(target_data_type_id = nil)
        sch = {
          SCHEMA_FLAG.to_s => true,
          type: 'object',
          properties: {
            source: {
              type: 'string',
              enum: enum = [],
              enumNames: enum_names = [],
              enumOptions: enum_options = []
            },
            transformation: {
              referenced: true,
              '$ref': { namespace: 'Setup', name: 'Translator' },
              filter: {
                '$and': [
                  { '$or': [
                    { source_data_type: { a: { v: '_blank' } } },
                    { source_data_type: { b: { v: '__source_data_type_id__' } } }
                  ] },
                  { '$or': type_conditions = [
                    { type: { c: { v: 'Export' } } }
                  ] }
                ]
              },
              contextual_params: {
                source_data_type_id: '__source_data_type_id__',
                target_data_type_id: target_data_type_id
              },
              types: types = Setup::Template.concrete_class_hierarchy.collect(&:to_s),
              data: { 'template-name': '__source_data_type_id__' }
            },
            options: { type: 'string', default: '' }
          }
        }
        if target_data_type_id
          types << Setup::Converter.to_s
          type_conditions << { '$and': [{ type: { d: { v: 'Conversion' } } }, { target_data_type: { e: { v: target_data_type_id } } }] }
        end
        sch
        if source_data_type
          enum << '$'
          enum_names << source_data_type.custom_title
          enum_options << { data: { 'template-value': source_data_type.id.to_s } }
          source_model = source_data_type.records_model
          titles = Set.new
          source_model.properties.each do |property|
            next unless (property_model = source_model.property_model(property))
            property_dt = property_model.data_type
            unless property_dt == source_data_type
              enum << property
              title = property_dt.schema['title'] || property.to_title
              if titles.include?(title)
                title = "#{title} (#{property.to_title})"
              end
              titles << title
              enum_names << "#{source_data_type.custom_title} | #{title}"
              enum_options << { data: { 'template-value': property_dt.id.to_s } }
            end
          end
        end
        sch.deep_stringify_keys!
      end

      def file_mapping_schema
        field_schema = { type: 'string' }
        if (source = auto_complete_source).present?
          field_schema['format'] = 'auto-complete'
          field_schema['source'] = source
          field_schema['anchor'] = '{{'
        end
        {
          type: 'object',
          properties: {
            _id: field_schema.merge(description: 'Match an existing ID to update an existing record'),
            filename: field_schema,
            contentType: field_schema,
            data: mapping_schema.merge('description' => "<strong>Define the file data from a #{source_data_type.custom_title} template</strong>")
          },
          required: %w(data)
        }.deep_stringify_keys!
      end

      def proto_schema
        if data_type.is_a?(Setup::FileDataType)
          file_mapping_schema
        else
          to_map_schema(super)
        end
      end

      def auto_complete_source
        if @parent_map_model
          @parent_map_model.auto_complete_source
        else
          @auto_complete_source ||= source_data_type.records_model.properties_schemas.collect do |property, property_schema|
            {
              'value' => "{{#{property}}}",
              'text' => "#{source_data_type.custom_title} | #{property_schema['title'] || property.to_title}"
            }
          end
        end
      end

      def to_map_schema(sch)
        if sch['type'] == 'object' && (properties = sch['properties']).is_a?(Hash)
          new_properties = {}
          id_optional = true
          properties.each do |property, property_schema|
            ref, property_dt = check_referenced_schema(property_schema)
            if ref && property_dt
              description = data_type.merge_schema(property_schema)['description']
              description = "#{description}<br><strong>Define a transformation from #{source_data_type.custom_title} to #{property_dt.custom_title}</strong>"
              property_schema = mapping_schema(property_dt.id.to_s).merge!('description' => description)
            else
              property_schema = data_type.merge_schema(property_schema)
              if property_schema['type'] == 'object' || property_schema['type'] == 'array'
                type = property_schema['type']
                property_schema.clear
                property_schema['type'] = type
              else
                id_optional = property_schema['type'].blank? if property == '_id'
                property_schema.reject! { |key, _| %w(title description edi).exclude?(key) }
                property_schema['type'] = 'string'
                if (source = auto_complete_source).present?
                  property_schema['format'] = 'auto-complete'
                  property_schema['source'] = source
                  property_schema['anchor'] = '{{'
                end
              end
              if property == '_id'
                property_schema['description'] = 'Match an existing ID to update an existing record'
              end
            end
            new_properties[property] = property_schema
          end
          sch['properties'] = new_properties
          if id_optional && (required = sch['required'])
            required.delete('_id')
            sch.delete('required') if required.empty?
          end
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
