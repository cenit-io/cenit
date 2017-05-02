module RailsAdmin
  module Models
    module Setup
      module ForeignNotification
        module WebHookNotificationAdmin
          extend ActiveSupport::Concern

          included do
            rails_admin do
              object_label_method { :label }
              label 'Web-Hook'
              weight 500

              fields :active, :data_type, :observers, :setting, :updated_at
            end
          end

        end
      end
    end
  end
end

