module Forms
  class ImportTranslatorSelector
    include Mongoid::Document

    belongs_to :translator, class_name: Setup::Translator.to_s

    field :data, type: String

    validates_presence_of :translator, :data

    rails_admin do
      visible false

      edit do
        field :translator do
          inline_edit false
          inline_add false
          associated_collection_cache_all false
          associated_collection_scope do
            Proc.new { |scope|
              scope = scope.where(type: :Import)
            }
          end
        end

        field :data do
          html_attributes do
            { cols: '74', rows: '15' }
          end
        end
      end
    end
  end
end