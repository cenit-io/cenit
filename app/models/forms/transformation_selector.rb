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
      data_type_id =
        if [:Export, :Conversion].include?(translator_type)
          :source_data_type_id
        else
          :target_data_type_id
        end
      opts =
        {
          type: translator_type,
          data_type_id.in => data_type_ids = [nil]
        }
      data_type_ids << data_type.id if data_type
      opts[:bulk_source] = true if translator_type == :Export && bulk_source
      opts
    end

    after_initialize do
      self.translator = Setup::Translator.where(translator_options).first unless translator.present?
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
          associated_collection_scope do
            limit = (associated_collection_cache_all ? nil : 30)
            translator_options = bindings[:object].translator_options
            Proc.new { |scope| scope.where(translator_options).limit(limit) }
          end
        end
        field :options
      end
    end
  end
end