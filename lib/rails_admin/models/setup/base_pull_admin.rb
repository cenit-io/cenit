module RailsAdmin
  module Models
    module Setup
      module BasePullAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Monitors'
            visible false
            label 'Pull'
            object_label_method { :to_s }

            configure :attempts_succeded, :text do
              label 'Attempts/Succedded'
            end

            configure :_type do
              pretty_value do
                value.split('::').last.to_title
              end
            end

            edit do
              field :description
              field :auto_retry
            end

            fields :_type, :pull_request, :pulled_request, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :notifications, :updated_at
          end
        end

      end
    end
  end
end
