module Setup
  class Translator < ReqRejValidator
    include CenitScoped

    Setup::Models.exclude_actions_for self, :edit
    BuildInDataType.regist(self).referenced_by(:name)

    field :name, type: String
    field :type, type: Symbol

    belongs_to :source_data_type, class_name: Setup::Model.to_s, inverse_of: nil
    belongs_to :target_data_type, class_name: Setup::Model.to_s, inverse_of: nil

    field :discard_events, type: Boolean
    field :style, type: String

    field :mime_type, type: String
    field :file_extension, type: String
    field :bulk_source, type: Boolean, default: false

    field :transformation, type: String

    belongs_to :source_exporter, class_name: Setup::Translator.to_s, inverse_of: nil
    belongs_to :target_importer, class_name: Setup::Translator.to_s, inverse_of: nil

    field :discard_chained_records, type: Boolean

    validates_uniqueness_of :name
    before_save :validates_configuration

    def validates_configuration
      requires(:name)
      errors.add(:type, 'is not valid') unless type_enum.include?(type)
      errors.add(:style, 'is not valid') unless style_enum.include?(style)
      case type
      when :Import, :Update
        rejects(:source_data_type, :mime_type, :file_extension, :bulk_source, :source_exporter, :target_importer, :discard_chained_records)
        requires(:transformation)
      when :Export
        rejects(:target_data_type, :source_exporter, :target_importer, :discard_chained_records)
        requires(:transformation)
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
        requires(:source_data_type, :target_data_type)
        if style == 'chain'
          requires(:source_exporter, :target_importer)
          if errors.blank?
            errors.add(:source_exporter, "can't be applied to #{source_data_type.title}") unless source_exporter.apply_to_source?(source_data_type)
            errors.add(:target_importer, "can't be applied to #{target_data_type.title}") unless target_importer.apply_to_target?(target_data_type)
          end
          self.transformation = "#{source_data_type.title} -> [#{source_exporter.name} : #{target_importer.name}] -> #{target_data_type.title}" if errors.blank?
        else
          requires(:transformation)
          rejects(:source_exporter, :target_importer)
        end
      end
      errors.blank?
    end

    def reject_message(field = nil)
      (style && type).present? ? "is not allowed for #{style} #{type.to_s.downcase} translators" : super
    end

    def type_enum
      [:Import, :Export, :Update, :Conversion]
    end

    def source_bulkable?
      type == :Export && !NON_BULK_SOURCE_STYLES.include?(style)
    end

    NON_BULK_SOURCE_STYLES = %w(double_curly_braces xslt)

    STYLES_MAP = {
      'double_curly_braces' => {Setup::Transformation::DoubleCurlyBracesConversionTransform => [:Conversion],
                                Setup::Transformation::DoubleCurlyBracesExportTransform => [:Export]},
      'liquid' => {Setup::Transformation::LiquidExportTransform => [:Export]},
      'xslt' => {Setup::Transformation::XsltConversionTransform => [:Conversion],
                 Setup::Transformation::XsltExportTransform => [:Export]},
      'json.rabl' => {Setup::Transformation::ActionViewTransform => [:Export]},
      'xml.rabl' => {Setup::Transformation::ActionViewTransform => [:Export]},
      'xml.builder' => {Setup::Transformation::ActionViewTransform => [:Export]},
      'html.haml' => {Setup::Transformation::ActionViewTransform => [:Export]},
      'html.erb' => {Setup::Transformation::ActionViewTransform => [:Export]},
      'csv.erb' => {Setup::Transformation::ActionViewTransform => [:Export]},
      'js.erb' => {Setup::Transformation::ActionViewTransform => [:Export]},
      'text.erb' => {Setup::Transformation::ActionViewTransform => [:Export]},
      'ruby' => {Setup::Transformation::ActionViewTransform => [:Import, :Export, :Update, :Conversion]},
      'pdf.prawn' => {Setup::Transformation::PrawnTransform => [:Export]},
      'chain' => {Setup::Transformation::ChainTransform => [:Conversion]}
    }

    EXPORT_MIME_FILTER = {
      'double_curly_braces' => ['application/json'],
      'liquid' => ['application/json'],
      'xslt' => ['application/xml'],
      'json.rabl' => ['application/json'],
      'xml.rabl' => ['application/xml'],
      'xml.builder' => ['application/xml'],
      'html.haml' => ['text/html'],
      'html.erb' => ['text/html'],
      'csv.erb' => ['text/csv'],
      'js.erb' => %w(application/x-javascript application/javascript text/javascript),
      'text.erb' => ['text/plain'],
      'pdf.prawn' => ['application/pdf']
    }

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
      if types = MIME::Types[mime_type]
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

    def run(options={})
      context_options = try("context_options_for_#{type.to_s.downcase}", options) || {}
      self.class.fields.keys.each { |key| context_options[key.to_sym] = send(key) }
      self.class.relations.keys.each { |key| context_options[key.to_sym] = send(key) }
      context_options[:data_type] = data_type
      context_options.merge!(options) { |key, context_val, options_val| !context_val ? options_val : context_val }

      context_options[:result] = STYLES_MAP[style].keys.detect { |t| STYLES_MAP[style][t].include?(type) }.run(context_options)

      try("after_run_#{type.to_s.downcase}", context_options)

      context_options[:result]
    end

    def context_options_for_import(options)
      raise Exception.new('Target data type not defined') unless data_type = target_data_type || options[:target_data_type]
      {target_data_type: data_type, targets: Set.new}
    end

    def context_options_for_export(options)
      raise Exception.new('Source data type not defined') unless data_type = source_data_type || options[:source_data_type]
      model = data_type.records_model
      offset = options[:offset] || 0
      limit = options[:limit]
      source_options =
        if bulk_source
          {sources: if object_ids = options[:object_ids]
                      model.any_in(id: (limit ? object_ids[offset, limit] : object_ids.from(offset))).to_enum
                    else
                      (limit ? model.limit(limit) : model.all).skip(offset).to_enum
                    end}
        else
          {source: options[:object] || ((id = (options[:object_id] || (options[:object_ids] && options[:object_ids][offset]))) && model.where(id: id).first) || model.all.skip(offset).first}
        end
      {source_data_type: data_type}.merge(source_options)
    end

    def context_options_for_update(options)
      {target: options[:object]}
    end

    def context_options_for_conversion(options)
      raise Exception.new("Target data type #{target_data_type.title} is not loaded") unless target_data_type.loaded?
      {source: options[:object], target: style == 'chain' ? nil : target_data_type.records_model.new}
    end

    def after_run_import(options)
      return unless targets = options[:targets]
      targets.each do |target|
        target.try(:discard_event_lookup=, options[:discard_events])
        raise TransformingObjectException.new(target) unless Cenit::Utility.save(target)
      end
      options[:result] = targets
    end

    def after_run_update(options)
      if target = options[:object]
        target.try(:discard_event_lookup=, options[:discard_events])
        raise TransformingObjectException.new(target) unless Cenit::Utility.save(target)
      end
      options[:result] = target
    end

    def after_run_conversion(options)
      return unless target = options[:target]
      if options[:save_result].blank? || options[:save_result]
        target.try(:discard_event_lookup=, options[:discard_events])
        raise TransformingObjectException.new(target) unless Cenit::Utility.save(target)
      end
      options[:result] = target
    end
  end

  class TransformingObjectException < Exception

    attr_reader :object

    def initialize(object)
      super "Error transforming object #{object}"
      @object = object
    end
  end
end