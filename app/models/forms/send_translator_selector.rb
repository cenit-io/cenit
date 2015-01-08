module Forms
  class SendTranslatorSelector
    include Mongoid::Document

    belongs_to :translator, class_name: Setup::Translator.to_s

    validates_presence_of :translator

    rails_admin do
      visible false

      edit do
        field :translator do
          associated_collection_cache_all false
          associated_collection_scope do
            Proc.new { |scope|
              scope = scope.where(purpose: :send)
            }
          end
        end
      end
    end
  end
end