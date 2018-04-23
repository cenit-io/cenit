module Forms
  class TransformationSelector
    include Mongoid::Document
    include TransformationOptions
    include AccountScoped

    field :translator_type, type: Symbol
    field :bulk_source, type: Boolean
    belongs_to :data_type, class_name: Setup::DataType.to_s, inverse_of: nil
    belongs_to :translator, class_name: Setup::Translator.to_s, inverse_of: nil

    def translator_options
      opts = { type: translator_type }
      opts[:bulk_source] = true if translator_type == :Export && bulk_source
      opts
    end

    validates_presence_of :translator_type, :translator

    validate do |selector|
      if selector.translator && selector.translator_type
        errors.add(:translator, "must be of type #{selector.translator_type}") unless selector.translator.type == selector.translator_type
      end
    end

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
      edit do
        field :translator do
          types do
            [
              {
                Export: [Setup::Renderer, Setup::Template.concrete_class_hierarchy].flatten,
                Conversion: Setup::Converter,
                Update: Setup::Updater
              }[bindings[:object].translator_type].to_s
            ]
          end
          contextual_params do
            if (data_type = bindings[:object].data_type)
              {
                if [:Export, :Conversion].include?(bindings[:object].translator_type)
                  :source_data_type_id
                else
                  :target_data_type_id
                end => [nil, data_type.id]
              }
            end
          end
          contextual_association_scope do
            translator_options = bindings[:object].translator_options
            Proc.new { |scope| scope.where(translator_options) }
          end
        end
        field :options
      end
    end
  end
end