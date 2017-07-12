module RailsAdmin
  module Models
    module Setup
      module EmailFlowAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            object_label_method { :custom_title }

            visible { User.current_super_admin? }

            fields :namespace, :name, :send_flow, :updated_at
          end
        end

      end
    end
  end
end
