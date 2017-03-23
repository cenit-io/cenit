module RailsAdmin
  module Models
    module Setup
      module WorkflowTransitionAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Transitions'
            weight 500
            object_label_method { :name }

            edit do
              field :description do
                required true
              end
              field :to_activity_id, :enum do
                required true
                enum do
                  workflow = bindings[:controller].instance_variable_get(:@object)
                  workflow.passable_activities.map { |a| [a.name, a.id] }
                end
              end
              field :is_default_transition
            end

          end
        end

      end
    end
  end
end
