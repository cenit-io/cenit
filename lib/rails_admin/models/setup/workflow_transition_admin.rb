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
              field :description
              field :to_activity do
                required true
                inline_add false
                inline_edit false
                associated_collection_scope do
                  workflow = bindings[:controller].instance_variable_get(:@object)
                  proc do
                    workflow.passable_activities
                  end
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
