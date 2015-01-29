module Setup
  class Translator
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Trackable

    field :name, type: String
    field :type, type: Symbol

    belongs_to :source_data_type, class_name: Setup::DataType.name
    belongs_to :target_data_type, class_name: Setup::DataType.name

    field :style, type: String
    field :transformation, type: String

    belongs_to :source_exporter, class_name: Setup::Translator.name
    belongs_to :target_importer, class_name: Setup::Translator.name

    validates_presence_of :name, :type, :style
    validates_inclusion_of :type, in: ->(t) { t.type_options }
    validates_inclusion_of :style, in: ->(t) { t.style_options }
    before_save :validates_definition

    def validates_definition
      if type == :Conversion
        [:source_data_type, :target_data_type].each do |field|
          errors.add(field, "can't be blank") if send(field).blank?
        end
        if errors.blank?
          errors.add(:target_data_type, 'must defers from source') if target_data_type == source_data_type
        end
        if style == 'chain'
          [:source_exporter, :target_importer].each do |field|
            errors.add(field, "can't be blank") if send(field).blank?
          end
          if errors.blank?
            errors.add(:source_exporter, "can't be applied to #{source_data_type.title}") unless source_exporter.apply_to_source?(source_data_type)
            errors.add(:target_importer, "can't be applied to #{target_data_type.title}") unless target_importer.apply_to_target?(target_data_type)
          end
          self.transformation = "#{source_data_type.title} -> #{source_exporter.name} -> #{target_importer.name} -> #{target_data_type.title}" if errors.blank?
        end
      end
      errors.blank?
    end

    def type_options
      [:Import, :Export, :Update, :Conversion]
    end

    def type_enum
      type.present? ? [type] : type_options
    end

    STYLES_MAP = {'renit' => Setup::Transformation::RenitTransform,
                  'double_curly_braces' => Setup::Transformation::DoubleCurlyBracesTransform,
                  'xslt' => Setup::Transformation::XsltTransform,
                  'json.rabl' => Setup::Transformation::ActionViewTransform,
                  'xml.rabl' => Setup::Transformation::ActionViewTransform,
                  'xml.builder' => Setup::Transformation::ActionViewTransform,
                  'html.erb' => Setup::Transformation::ActionViewTransform,
                  'chain' => Setup::Transformation::ChainTransform}

    def style_options
      styles = []
      unless type.blank?
        STYLES_MAP.each do |key, value|
          styles << key if value.types.include?(type)
        end
      end
      styles.uniq
    end

    def style_enum
      style.present? ? [style] : style_options
    end

    def ready_to_save?
      type.present? && style.present?
    end

    def can_be_restarted?
      type.present?
    end

    def apply_to_source?(data_type)
      source_data_type.blank? || source_data_type == data_type
    end

    def apply_to_target?(data_type)
      target_data_type.blank? || target_data_type == data_type
    end

    def run(options={})
      target = nil
      if type == :Conversion
        raise Exception.new("Target data type #{target_data_type.title} is not loaded") unless target_data_type.loaded?
        target = target_data_type.model.new
      end
      context_options = {target: target}
      [:type, :style, :source_data_type, :target_data_type, :source_exporter, :target_importer, :transformation].each do |field|
        context_options[field] = send(field)
      end
      result = STYLES_MAP[style].run options.merge(context_options) { |key, old_val, new_val| new_val || old_val }
      case type
        when :Update
          unless (object = options[:object]).save
            raise TransformingObjectException.new(object)
          end
        when :Conversion
          unless target.save
            raise TransformingObjectException.new(target)
          end
      end
      result
    end

    rails_admin do

      edit do
        field :name

        field :type

        field :source_data_type do
          inline_edit false
          inline_add false
          visible { [:Export, :Conversion].include?(bindings[:object].type) }
          help { bindings[:object].type == :Conversion ? 'Required' : 'Optional' }
        end

        field :target_data_type do
          inline_edit false
          inline_add false
          visible { [:Import, :Update, :Conversion].include?(bindings[:object].type) }
          help { bindings[:object].type == :Conversion ? 'Required' : 'Optional' }
        end

        field :style do
          visible { bindings[:object].type.present? }
        end

        field :transformation do
          visible { bindings[:object].style.present? && bindings[:object].style != 'chain' }
          html_attributes do
            {cols: '74', rows: '15'}
          end
        end

        field :source_exporter do
          inline_edit false
          inline_add false
          visible { bindings[:object].style == 'chain' }
          help 'Required'
          associated_collection_cache_all false
          associated_collection_scope do
            Proc.new { |scope|
              scope = scope.where(type: :Export)
            }
          end
        end

        field :target_importer do
          inline_edit false
          inline_add false
          visible { bindings[:object].style == 'chain' }
          help 'Required'
          associated_collection_cache_all false
          associated_collection_scope do
            Proc.new { |scope|
              scope = scope.where(type: :Import)
            }
          end
        end
      end

      show do
        field :name
        field :type
        field :style
        field :transformation

        field :_id
        field :created_at
        field :creator
        field :updated_at
        field :updater
      end

      fields :name, :type, :style, :transformation
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