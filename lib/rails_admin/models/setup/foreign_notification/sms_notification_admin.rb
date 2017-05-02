module RailsAdmin
  module Models
    module Setup
      module ForeignNotification
        module SmsNotificationAdmin
          extend ActiveSupport::Concern

          included do
            rails_admin do
              object_label_method { :label }
              label 'SMS'
              weight 500

              fields :active, :data_type, :observers, :setting, :updated_at
            end
          end

        end
      end
    end
  end
end

