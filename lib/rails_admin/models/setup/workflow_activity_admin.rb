module RailsAdmin
  module Models
    module Setup
      module WorkflowActivityAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Activities'
            weight 500
            object_label_method { :name }

            edit do
              field :name do
                required true
              end
              field :type, :enum do
                required true
                read_only do
                  !bindings[:object].new_record?
                end
              end
              field :description do
                required true
                visible do
                  !(bindings[:object].is_start_event? || bindings[:object].is_end_event?)
                end
              end
              field :attrs
              field :transitions do
                required true
                visible do
                  !(bindings[:object].new_record? || bindings[:object].is_end_event?)
                end
              end
            end

          end
        end

      end
    end
  end
end
