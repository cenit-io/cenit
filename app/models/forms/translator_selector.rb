module Forms
  class TranslatorSelector
    include Mongoid::Document

    field :translator_type, type: Symbol
    field :bulk_source, type: Boolean
    belongs_to :data_type, class_name: Setup::DataType.to_s, inverse_of: nil
    belongs_to :translator, class_name: Setup::Translator.to_s, inverse_of: nil

    after_initialize do
      unless translator.present?
        data_type_criteria =
            case translator_type
              when :Export, :Conversion
                :source_data_type
              when :Import, :Update
                :target_data_type
            end

        if data_type_criteria
          self.translator = Setup::Translator.all.any_in(data_type_criteria => [nil, data_type]).and(type: translator_type).first
        else
          self.translator = Setup::Translator.all(type: translator_type).first
        end
      end
    end

    validates_presence_of :translator_type, :translator
    validate do |selector|
      if selector.translator && selector.translator_type
        errors.add(:translator, "must be of type #{selector.translator_type}") unless selector.translator.type == selector.translator_type
      end
    end

    rails_admin do
      visible false
      edit do
        field :translator do
          associated_collection_scope do
            data_type = bindings[:object].try(:data_type)
            bulk_source = bindings[:object].try(:bulk_source)
            data_type_criteria =
                case translator_type = bindings[:object].try(:translator_type)
                  when :Export, :Conversion
                    :source_data_type
                  when :Import, :Update
                    :target_data_type
                end
            Proc.new { |scope|
              scope =
                  if data_type_criteria
                    scope.any_in(data_type_criteria => [nil, data_type]).and(type: translator_type)
                  else
                    scope.all(type: translator_type)
                  end
              if translator_type == :Export && bulk_source
                scope = scope.and(bulk_source: true)
              end
              scope
            }
          end
        end
      end
    end
  end
end