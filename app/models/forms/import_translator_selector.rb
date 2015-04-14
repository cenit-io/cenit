module Forms
  class ImportTranslatorSelector
    include Mongoid::Document

    belongs_to :data_type, class_name: Setup::Model.to_s, inverse_of: nil
    belongs_to :translator, class_name: Setup::Translator.to_s, inverse_of: nil

    field :data, type: String

    validates_presence_of :translator, :data

    rails_admin do
      visible false

      edit do
        field :translator do
          inline_edit false
          inline_add false
          associated_collection_scope do
            data_type = bindings[:object].try(:data_type)
            Proc.new { |scope|
              scope.any_in(target_data_type: [nil, data_type]).and(type: :Import)
            }
          end
        end

        field :data do
          html_attributes do
            {cols: '74', rows: '15'}
          end
        end
      end
    end
  end
end
