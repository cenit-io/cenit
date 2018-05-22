module RailsAdmin
  module Models
    module Setup
      module EmailChannelAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Workflows'
            navigation_icon 'fa fa-envelope-o'
            weight 450
            object_label_method { :custom_title }

            configure :namespace, :enum_edit

            fields :namespace, :name, :updated_at
          end
        end

      end
    end
  end
end
