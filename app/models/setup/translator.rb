module Setup
  class Translator < ReqRejValidator
    include CenitScoped

    Setup::Models.exclude_actions_for self, :edit
    BuildInDataType.regist(self).referenced_by(:name)

    field :name, type: String
    field :type, type: Symbol

    belongs_to :source_data_type, class_name: Setup::DataType.to_s, inverse_of: nil
    belongs_to :target_data_type, class_name: Setup::DataType.to_s, inverse_of: nil

    field :discard_events, type: Boolean
    field :style, type: String

    field :mime_type, type: String
    field :file_extension, type: String
    field :bulk_source, type: Boolean

    field :transformation, type: String

    belongs_to :source_exporter, class_name: Setup::Translator.to_s, inverse_of: nil
    belongs_to :target_importer, class_name: Setup::Translator.to_s, inverse_of: nil

    field :discard_chained_records, type: Boolean

    belongs_to :cenit_collection, class_name: Setup::Collection.to_s, inverse_of: :translators

    validates_account_uniqueness_of :name
    before_save :validates_configuration

    def validates_configuration
      return false unless ready_to_save?
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

    STYLES_MAP = {
      'renit' => Setup::Transformation::RenitTransform,
      'double_curly_braces' => Setup::Transformation::DoubleCurlyBracesTransform,
      'xslt' => Setup::Transformation::XsltTransform,
      'json.rabl' => Setup::Transformation::ActionViewTransform,
      'xml.rabl' => Setup::Transformation::ActionViewTransform,
      'xml.builder' => Setup::Transformation::ActionViewTransform,
      'html.haml' => Setup::Transformation::ActionViewTransform,
      'html.erb' => Setup::Transformation::ActionViewTransform,
      'ruby' => Setup::Transformation::ActionViewTransform,
      'pdf.prawn' => Setup::Transformation::PrawnTransform,
      'chain' => Setup::Transformation::ChainTransform}

    def style_enum
      styles = []
      STYLES_MAP.each { |key, value| styles << key if value.types.include?(type) } if type.present?
      styles.uniq
    end

    def mime_type_enum
      MIME::Types.inject([]) { |types, t| types << t.to_s }
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

      context_options[:result] = STYLES_MAP[style].run(context_options)

      try("after_run_#{type.to_s.downcase}", context_options)

      context_options[:result]
    end

    def context_options_for_import(options)
      raise Exception.new('Target data type not defined') unless data_type = target_data_type || options[:target_data_type]
      {target_data_type: data_type}
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
        raise TransformingObjectException.new(target) unless Translator.save(target)
      end
      options[:result] = targets
    end

    def after_run_update(options)
      if target = options[:object]
        target.try(:discard_event_lookup=, options[:discard_events])
        raise TransformingObjectException.new(target) unless Translator.save(target)
      end
      options[:result] = target
    end

    def after_run_conversion(options)
      return unless target = options[:target]
      if options[:save_result].blank? || options[:save_result]
        target.try(:discard_event_lookup=, options[:discard_events])
        raise TransformingObjectException.new(target) unless Translator.save(target)
      end
      options[:result] = target
    end

    private

    class << self
      def save(record)
        saved = Set.new
        if bind_references(record)
          if save_references(record, saved) && (saved.include?(record) || record.save)
            true
          else
            for_each_node_starting_at(record, stack=[]) do |obj|
              obj.errors.each do |attribute, error|
                attr_ref = "#{obj.orm_model.data_type.title}" +
                  ((name = obj.try(:name)) || (name = obj.try(:title)) ? " #{name} on attribute " : "'s '") +
                  attribute.to_s + ((v = obj.try(attribute)) ? "'#{v}'" : '')
                path = ''
                stack.reverse_each do |node|
                  node[:record].errors.add(node[:attribute], "with error on #{path}#{attr_ref} (#{error})") if node[:referenced]
                  path = node[:record].orm_model.data_type.title + ' -> '
                end
              end
            end
            saved.each { |obj| obj.delete unless obj.deleted? }
            false
          end
        else
          false
        end
      end

      def bind_references(record)
        references = {}
        for_each_node_starting_at(record) do |obj|
          if record_refs = obj.instance_variable_get(:@_references)
            references[obj] = record_refs
          end
        end
        puts references
        for_each_node_starting_at(record) do |obj|
          references.each do |obj_waiting, to_bind|
            to_bind.each do |property_name, property_binds|
              is_array = property_binds.is_a?(Array) ? true : (property_binds = [property_binds]; false)
              property_binds.each do |property_bind|
                if obj.is_a?(property_bind[:model]) && match?(obj, property_bind[:criteria])
                  if is_array
                    unless array_property = obj_waiting.send(property_name)
                      obj_waiting.send("#{property_name}=", array_property = [])
                    end
                    array_property << obj
                  else
                    obj_waiting.send("#{property_name}=", obj)
                  end
                  property_binds.delete(property_bind)
                end
                to_bind.delete(property_name) if property_binds.empty?
              end
              references.delete(obj_waiting) if to_bind.empty?
            end
          end
        end if references

        for_each_node_starting_at(record, stack = []) do |obj|
          if to_bind = references[obj]
            to_bind.each do |property_name, property_binds|
              property_binds = [property_binds] unless property_binds.is_a?(Array)
              property_binds.each do |property_bind|
                message = "reference not found with criteria #{property_bind[:criteria].to_json}"
                obj.errors.add(property_name, message)
                stack.each { |node| node[:record].errors.add(node[:attribute], message) }
              end
            end
          end
        end if references
        record.errors.blank?
      end

      def match?(obj, criteria)
        criteria.each { |property_name, value| return false unless obj.try(property_name) == value }
        true
      end

      def for_each_node_starting_at(record, stack = nil, visited = Set.new, &block)
        visited << record
        block.yield(record) if block
        if orm_model = record.try(:orm_model)
          orm_model.for_each_association do |relation|
            if values = record.send(relation[:name])
              stack << {record: record, attribute: relation[:name], referenced: !relation[:embedded]} if stack
              values = [values] unless values.is_a?(Enumerable)
              values.each { |value| for_each_node_starting_at(value, stack, visited, &block) unless visited.include?(value) }
              stack.pop if stack
            end
          end
        end
      end

      def save_references(record, saved, visited = Set.new)
        return true if visited.include?(record)
        visited << record
        record.orm_model.for_each_association do |relation|
          next if Setup::BuildInDataType::EXCLUDED_RELATIONS.include?(relation[:name].to_s)
          if values = record.send(relation[:name])
            values = [values] unless values.is_a?(Enumerable)
            values.each { |value| return false unless save_references(value, saved, visited) }
            values.each do |value|
              (value.save ? saved << value : (return false)) unless saved.include?(value)
            end unless relation[:embedded]
          end
        end
        true
      end
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