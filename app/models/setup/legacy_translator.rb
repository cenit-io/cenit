module Setup
  class LegacyTranslator < Translator
    include ReqRejValidator
    include SnippetCode
    include RailsAdmin::Models::Setup::TranslatorAdmin
    # = Translator
    #
    # A translator defines a logic for data manipulation

    abstract_class true

    legacy_code_attribute :transformation

    field :type, type: Symbol, default: -> { self.class.transformation_type }

    belongs_to :source_data_type, class_name: Setup::DataType.to_s, inverse_of: nil
    belongs_to :target_data_type, class_name: Setup::DataType.to_s, inverse_of: nil

    field :discard_events, type: Boolean
    field :style, type: String

    field :mime_type, type: String
    field :file_extension, type: String
    field :bulk_source, type: Boolean, default: false

    field :source_handler, type: Boolean

    belongs_to :source_exporter, class_name: Setup::Translator.to_s, inverse_of: nil
    belongs_to :target_importer, class_name: Setup::Translator.to_s, inverse_of: nil

    field :discard_chained_records, type: Boolean

    before_save :validates_configuration, :validates_code

    def validates_configuration
      requires(:name)
      errors.add(:type, 'is not valid') unless type_enum.include?(type)
      errors.add(:style, 'is not valid') unless style_enum.include?(style)
      case type
      when :Import, :Update
        rejects(:source_data_type, :mime_type, :file_extension, :bulk_source, :source_exporter, :target_importer, :discard_chained_records)
        requires(:code)
        rejects(:source_handler) if type == :Import
      when :Export
        rejects(:target_data_type, :source_handler, :source_exporter, :target_importer, :discard_chained_records)
        requires(:code)
        if bulk_source && NON_BULK_SOURCE_STYLES.include?(style)
          errors.add(:bulk_source, "is not allowed with '#{style}' style")
          self.bulk_source = false
        end
        if mime_type.present?
          if (extensions = file_extension_enum).empty?
            self.file_extension = nil
          elsif file_extension.blank?
            extensions.length == 1 ? (self.file_extension = extensions[0]) : errors.add(:file_extension, 'has multiple options')
          else
            errors.add(:file_extension, 'is not valid') unless extensions.include?(file_extension)
          end
        end
      when :Conversion
        rejects(:mime_type, :file_extension, :bulk_source)
        requires(:source_data_type)
        requires(:target_data_type) unless source_handler
        if style == 'chain'
          requires(:source_exporter, :target_importer)
          rejects(:source_handler)
          if errors.blank?
            errors.add(:source_exporter, "can't be applied to #{source_data_type.title}") unless source_exporter.apply_to_source?(source_data_type)
            errors.add(:target_importer, "can't be applied to #{target_data_type.title}") unless target_importer.apply_to_target?(target_data_type)
          end
          self.code = "#{source_data_type.title} -> [#{source_exporter.name} : #{target_importer.name}] -> #{target_data_type.title}" if errors.blank?
        elsif style == 'mapping'
          self.code = "Mapping #{source_data_type.title} to #{target_data_type.title}" if errors.blank?
        else
          requires(:code)
          rejects(:source_exporter, :target_importer)
          rejects(:source_handler) unless style == 'ruby'
        end
      end
      errors.blank?
    end

    def validates_code
      if style == 'ruby'
        Capataz.validate(code).each { |error| errors.add(:code, error) }
      end
      errors.blank?
    end

    def reject_message(field = nil)
      (style && type).present? ? "is not allowed for #{style} #{type.to_s.downcase} translators" : super
    end

    def source_bulkable?
      type == :Export && !NON_BULK_SOURCE_STYLES.include?(style)
    end

    NON_BULK_SOURCE_STYLES = %w(double_curly_braces xslt liquid)

    STYLES_MAP = {
      'liquid' => { Setup::Transformation::LiquidExportTransform => [:Export],
        Setup::Transformation::LiquidConversionTransform => [:Conversion] },
      'xslt' => { Setup::Transformation::XsltConversionTransform => [:Conversion],
        Setup::Transformation::XsltExportTransform => [:Export] },
      # 'json.rabl' => {Setup::Transformation::ActionViewTransform => [:Export]},
      # 'xml.rabl' => {Setup::Transformation::ActionViewTransform => [:Export]},
      # 'xml.builder' => {Setup::Transformation::ActionViewTransform => [:Export]},
      # 'html.haml' => {Setup::Transformation::ActionViewTransform => [:Export]},
      'html.erb' => { Setup::Transformation::ActionViewTransform => [:Export] },
      # 'csv.erb' => {Setup::Transformation::ActionViewTransform => [:Export]},
      'js.erb' => { Setup::Transformation::ActionViewTransform => [:Export] },
      # 'text.erb' => {Setup::Transformation::ActionViewTransform => [:Export]},
      'ruby' => { Setup::Transformation::Ruby => [:Import, :Export, :Update, :Conversion] },
      'pdf.prawn' => { Setup::Transformation::PrawnTransform => [:Export] },
      'chain' => { Setup::Transformation::ChainTransform => [:Conversion] },
      'mapping' => { Setup::Transformation::MappingTransform => [:Conversion] }
    }

    def code_extension
      case style
      when 'ruby', 'pdf.prawn'
        '.rb'
      when 'chain'
        ''
      else
        ".#{style}"
      end
    end

    EXPORT_MIME_FILTER = {
      'double_curly_braces': ['application/json'],
      'xslt': %w(application/xml text/html),
      'json.rabl': ['application/json'],
      'xml.rabl': ['application/xml'],
      'xml.builder': ['application/xml'],
      'html.haml': ['text/html'],
      'html.erb': ['text/html'],
      'csv.erb': ['text/csv'],
      'js.erb': %w(application/x-javascript application/javascript text/javascript),
      'text.erb': ['text/plain'],
      'pdf.prawn': ['application/pdf']
    }.stringify_keys

    def style_enum
      styles = []
      STYLES_MAP.each { |key, value| styles << key if value.values.detect { |types| types.include?(type) } } if type.present?
      styles.uniq
    end

    def mime_type_enum
      EXPORT_MIME_FILTER[style] || MIME::Types.inject([]) { |types, t| types << t.to_s }
    end

    def file_extension_enum
      extensions = []
      if (types = MIME::Types[mime_type])
        types.each { |type| extensions.concat(type.extensions) }
      end
      extensions.uniq
    end

    def ready_to_save?
      (type && style).present? && (style != 'chain' || (source_data_type && target_data_type && source_exporter).present?)
    end

    def can_be_restarted?
      type.present?
    end

    def data_type
      (type == :Import || type == :Update) ? target_data_type : source_data_type
    end

    def apply_to_source?(data_type)
      source_data_type.blank? || source_data_type == data_type
    end

    def apply_to_target?(data_type)
      target_data_type.blank? || target_data_type == data_type
    end

    def run(options = {})
      context_options = try("context_options_for_#{type.to_s.downcase}", options) || {}
      self.class.fields.keys.each { |key| context_options[key.to_sym] = send(key) }
      self.class.relations.keys.each { |key| context_options[key.to_sym] = send(key) }
      context_options[:data_type] = data_type
      context_options.merge!(options) { |_, context_val, options_val| !context_val ? options_val : context_val }
      context_options[:options] ||= {}
      # TODO: Remove transformation local after migration
      context_options[:transformation] = context_options[:code] = code

      context_options[:target_data_type].regist_creation_listener(self) if context_options[:target_data_type]
      context_options[:source_data_type].regist_creation_listener(self) if context_options[:source_data_type]
      context_options[:translator] = self

      context_options[:result] = STYLES_MAP[style].keys.detect { |t| STYLES_MAP[style][t].include?(type) }.run(context_options)

      context_options[:target_data_type].unregist_creation_listener(self) if context_options[:target_data_type]
      context_options[:source_data_type].unregist_creation_listener(self) if context_options[:source_data_type]

      try("after_run_#{type.to_s.downcase}", context_options)

      context_options[:result]
    end

    def before_create(record)
      record.instance_variable_set(:@discard_event_lookup, true) if discard_events
      if type == :Conversion && discard_chained_records
        record.orm_model.data_type == target_data_type
      else
        true
      end
    end

    def context_options_for_import(options)
      raise Exception.new('Target data type not defined') unless (data_type = target_data_type || options[:target_data_type])
      { target_data_type: data_type, targets: Set.new }
    end

    def source_options(options, source_key_options)
      data_type_key = source_key_options[:data_type_key] || :source_data_type
      if (data_type = send(data_type_key) || options[data_type_key] || options[:data_type])
        model = data_type.records_model
        offset = options[:offset] || 0
        limit = options[:limit]
        source_options =
          if source_key_options[:bulk]
            {
              source_key_options[:sources_key] || :sources =>
                if (object_ids = options[:object_ids])
                  model.any_in(id: (limit ? object_ids[offset, limit] : object_ids.from(offset))).to_enum
                elsif (objects = options[:objects])
                  objects
                else
                  enum = (limit ? model.limit(limit) : model.all).skip(offset).to_enum
                  options[:object_ids] = enum.collect { |obj| obj.id.is_a?(BSON::ObjectId) ? obj.id.to_s : obj.id }
                  enum
                end
            }
          else
            {
              source_key_options[:source_key] || :source =>
                begin
                  obj = options[:object] ||
                    ((id = (options[:object_id] || (options[:object_ids] && options[:object_ids][offset]))) && model.where(id: id).first) ||
                    model.all.skip(offset).first
                  options[:object_ids] = [obj.id.is_a?(BSON::ObjectId) ? obj.id.to_s : obj.id] unless options[:object_ids] || obj.nil?
                  obj
                end
            }
          end
        { source_data_type: data_type }.merge(source_options)
      else
        {}
      end
    end

    def context_options_for_export(options)
      source_options(options, bulk: bulk_source)
    end

    def context_options_for_update(options)
      source_options(options, data_type_key: :target_data_type, bulk: source_handler, sources_key: :targets, source_key: :target)
    end

    def context_options_for_conversion(options)
      if source_handler
        source_options(options, bulk: true)
      else
        { source: options[:object], target: style == 'ruby' ? target_data_type.records_model.new : nil }
      end
    end

    def after_run_update(options)
      if (target = options[:object])
        target.instance_variable_set(:@discard_event_lookup, options[:discard_events])
        fail TransformingObjectException.new(target) unless Cenit::Utility.save(target)
      end
      options[:result] = target
    end

    def after_run_conversion(options)
      return unless (target = options[:target])
      if options[:save_result].blank? || options[:save_result]
        target.instance_variable_set(:@discard_event_lookup, options[:discard_events])
        fail TransformingObjectException.new(target) unless Cenit::Utility.save(target)
      end
      options[:result] = target
    end

    def link?(call_symbol)
      link(call_symbol).present?
    end

    def link(call_symbol)
      Setup::Algorithm.where(name: call_symbol).first
    end

    def linker_id
      't' + id.to_s
    end

    class << self

      def mime_type_filter_enum
        Setup::Renderer.where(:mime_type.ne => nil).distinct(:mime_type).flatten.uniq
      end

      def file_extension_filter_enum
        Setup::Renderer.where(:file_extension.ne => nil).distinct(:file_extension).flatten.uniq
      end
    end
  end

  class TransformingObjectException < Exception

    attr_reader :object

    def initialize(object)
      msg =
        if object.new_record?
          "Creating object of type #{object.orm_model.data_type.custom_title}: "
        else
          "Transforming object #{object.id} of type #{object.orm_model.data_type.custom_title}: "
        end + object.errors.full_messages.to_sentence
      @object = object
      super(msg)
    end

  end
end
