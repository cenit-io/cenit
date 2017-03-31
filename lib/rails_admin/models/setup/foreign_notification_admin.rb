module RailsAdmin
  module Models
    module Setup
      module ForeignNotificationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Notifications'
            object_label_method { :label }
            weight 500

            edit do
              field :data_type
              field :type
              field :setting
              field :observers do
                help 'To use a newly created observer in this session, you must first use the save and edit action.'
              end
            end

          end
        end

      end
    end
  end
end
