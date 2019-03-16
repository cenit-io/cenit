module RailsAdmin
  module Models
    module Setup
      module TemplateAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Transforms'
            label 'Template'
            navigation_icon 'fa fa-file-code-o'
            visible { ::User.current_super_admin? && group_visible }
            weight 410
            object_label_method { :custom_title }


            fields :namespace, :name, :source_data_type, :mime_type, :file_extension, :updated_at
          end
        end
      end
    end
  end
end
