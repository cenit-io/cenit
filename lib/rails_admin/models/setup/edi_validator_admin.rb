module RailsAdmin
  module Models
    module Setup
      module EdiValidatorAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 103
            parent ::Setup::Validator
            object_label_method { :custom_title }
            label 'EDI Validator'

            edit do
              field :namespace, :enum_edit
              field :name
              field :schema_data_type
              field :content_type
            end

            fields :namespace, :name, :schema_data_type, :content_type, :updated_at
          end
        end

      end
    end
  end
end
