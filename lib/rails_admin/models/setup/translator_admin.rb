module RailsAdmin
  module Models
    module Setup
      module TranslatorAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Transforms'
            label 'Transformation'
            visible false
            weight 410
            object_label_method { :custom_title }


            fields :namespace, :name, :type, :updated_at
          end
        end

      end
    end
  end
end
