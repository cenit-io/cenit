module RailsAdmin
  module Models
    module Setup
      module ParserTransformationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Transforms'
            label 'Parser'
            navigation_icon 'fa fa-sign-in'
            visible { User.current_super_admin? && group_visible }
            weight 410
            object_label_method { :custom_title }


            fields :namespace, :name, :target_data_type, :updated_at
          end
        end

      end
    end
  end
end
