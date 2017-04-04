module RailsAdmin
  module Models
    module Setup
      module ForeignNotificationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            object_label_method { :label }
            label 'Notification'
            weight 500

            edit do
              field :data_type
              field :type
              field :active
              field :setting
              field :observers do
                label 'Events'
                inline_add false
                associated_collection_scope do
                  data_type = bindings[:object].data_type || bindings[:controller].object
                  Proc.new { |scope| scope.where(data_type_id: data_type.id) }
                end
                help 'To use a newly created observer in this session, you must first use the save and edit action.'
              end
            end

          end
        end

      end
    end
  end
end
