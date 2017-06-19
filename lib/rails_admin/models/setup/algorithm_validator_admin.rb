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
            configure :namespace, :enum_edit
            edit do
              field :namespace
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
