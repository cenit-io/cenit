module RailsAdmin
  module Models
    module Setup
      module EdiValidatorAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 103
            parent ::Setup::Validator
            navigation_label 'Definitions'
            navigation_icon 'fa fa-check-square-o'
            object_label_method { :custom_title }
            label 'EDI Validator'

            configure :namespace, :enum_edit

            edit do
              field :namespace
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
