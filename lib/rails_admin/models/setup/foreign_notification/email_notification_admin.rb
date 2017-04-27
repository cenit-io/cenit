module RailsAdmin
  module Models
    module Setup
      module ForeignNotification
        module EmailNotificationAdmin
          extend ActiveSupport::Concern

          included do
            rails_admin do
              object_label_method { :label }
              label 'Email'
            end
          end

        end
      end
    end
  end
end

