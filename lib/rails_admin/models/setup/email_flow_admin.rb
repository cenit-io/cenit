module RailsAdmin
  module Models
    module Setup
      module EmailFlowAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Workflows'
            object_label_method { :custom_title }

            fields :namespace, :name, :send_flow, :updated_at
          end
        end

      end
    end
  end
end
