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
            end
          end

        end
      end
    end
  end
end

