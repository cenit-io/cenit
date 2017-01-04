module RailsAdmin
  module Models
    module Setup
      module FlowExecutionAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Monitors'
            object_label_method { :to_s }
            parent 'Monitors'
            weight 611
            show_in_dashboard false

            configure :attempts_succeded, :text do
              label 'Attempts/Succedded'
            end

            edit do
              field :description
              field :auto_retry
            end

            fields :flow, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications, :updated_at
          end
        end

      end
    end
  end
end
