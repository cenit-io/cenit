module RailsAdmin
  module Models
    module ScriptExecutionAdmin
      extend ActiveSupport::Concern

      included do
        rails_admin do
          weight 840
          parent { nil }
          navigation_label 'Administration'
          object_label_method { :to_s }
          visible { ::User.current_super_admin? }

          configure :attempts_succeded, :text do
            label 'Attempts/Succedded'
          end

          edit do
            field :description
          end

          list do
            field :script
            field :description
            field :scheduler
            field :attempts_succeded
            field :retries
            field :progress
            field :status
            field :updated_at
          end

          fields :script, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :executions, :notifications
        end
      end
    end
  end
end
