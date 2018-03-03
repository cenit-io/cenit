module RailsAdmin
  module Models
    module Setup
      module ConverterTransformationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Transforms'
            navigation_icon 'fa fa-files-o'
            label 'Converter'
            visible false
            weight 410
            object_label_method { :custom_title }

            visible { User.current_super_admin? && group_visible }

            configure :namespace, :enum_edit

            fields :namespace, :name, :source_data_type, :target_data_type, :updated_at
          end
        end

      end
    end
  end
end
