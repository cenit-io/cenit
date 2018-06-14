module RailsAdmin
  module Models
    module Setup
      module WebhookAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            label 'All Webhook'
            visible false
            object_label_method { :custom_title }

            configure :namespace, :enum_edit
            configure :path
            # configure :method
            configure :description
            configure :_type do
              label 'Type'
              pretty_value do
                value.to_s.split('::').last.to_title
              end
            end

            fields :namespace, :path, :description, :_type, :updated_at
          end
        end

      end
    end
  end
end
