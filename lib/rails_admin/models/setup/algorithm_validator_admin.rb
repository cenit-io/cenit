module RailsAdmin
  module Models
    module Setup
      module AlgorithmValidatorAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            parent ::Setup::Validator
            weight 104
            label 'Algorithm Validator'
            object_label_method { :custom_title }
            edit do
              field :namespace, :enum_edit
              field :name
              field :algorithm
            end

            fields :namespace, :name, :algorithm, :updated_at
          end
        end

      end
    end
  end
end
