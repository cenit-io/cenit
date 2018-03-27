module RailsAdmin
  module Models
    module Setup
      module UpdaterTransformationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Transforms'
            navigation_icon 'fa fa-refresh'
            label 'Updater'
            weight 413
            object_label_method { :custom_title }

            visible { User.current_super_admin? && group_visible }

            configure :namespace, :enum_edit

            fields :namespace, :name, :target_data_type, :discard_events, :updated_at
          end
        end

      end
    end
  end
end
