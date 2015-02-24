module Forms
  class TranslatorSelector
    include Mongoid::Document

    field :translator_type, type: Symbol
    belongs_to :data_type, class_name: Setup::DataType.to_s, inverse_of: nil
    belongs_to :translator, class_name: Setup::Translator.to_s, inverse_of: nil

    validates_presence_of :translator_type, :data_type, :translator

    rails_admin do
      visible false

      edit do
        field :translator do
          inline_edit false
          inline_add false
          associated_collection_scope do
            data_type = bindings[:object].try(:data_type)
            data_type_criteria = case translator_type = bindings[:object].try(:translator_type)
                                   when :Export, :Conversion
                                     :source_data_type
                                   when :Import, :Update
                                     :target_data_type
                                 end
            Proc.new { |scope|
              if data_type_criteria
                scope.any_in(data_type_criteria => [nil, data_type]).and(type: translator_type)
              else
                scope.all(type: translator_type)
              end
            }
          end
        end
      end
    end
  end
end