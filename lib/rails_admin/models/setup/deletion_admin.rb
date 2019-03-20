module RailsAdmin
  module Models
    module Setup
      module DeletionAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Monitors'
            visible false
            object_label_method { :to_s }
            configure :attempts_succeded, :text do
              label 'Attempts/Succedded'
            end
            configure :deletion_model do
              label 'Model'
              pretty_value do
                if value
                  v = bindings[:view]
                  amc = RailsAdmin.config(value)
                  am = amc.abstract_model
                  wording = amc.navigation_label + ' > ' + amc.label
                  can_see = !am.embedded? && (index_action = v.action(:index, am))
                  (can_see ? v.link_to(amc.contextualized_label(:menu), v.url_for(action: index_action.action_name, model_name: am.to_param), class: 'pjax') : wording).html_safe
                end
              end
            end

            edit do
              field :description
              field :auto_retry
            end

            list do
              field :deletion_model
              field :description
              field :scheduler
              field :attempts_succeded
              field :retries
              field :progress
              field :status
              field :updated_at
            end

            fields :deletion_model, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :executions, :notifications, :updated_at
          end
        end
      end
    end
  end
end
