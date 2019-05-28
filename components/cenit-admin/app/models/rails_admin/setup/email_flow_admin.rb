module RailsAdmin
  module Models
    module Setup
      module EmailFlowAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Workflows'
            navigation_icon 'fa fa-share'
            object_label_method { :custom_title }

            configure :namespace, :enum_edit

            fields :namespace, :name, :send_flow, :updated_at
          end
        end
      end
    end
  end
end
