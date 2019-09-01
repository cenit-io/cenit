module RailsAdmin
  module Models
    module Setup
      module HookDataProcessingAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Monitors'
            visible false
            object_label_method { :to_s }

            configure :attempts_succeded, :text do
              label 'Attempts/Succedded'
            end

            configure :data, :text

            edit do
              field :description
              field :auto_retry
            end

            list do
              field :hook
              field :slug
              field :data
              field :attempts_succeded
              field :retries
              field :progress
              field :status
              field :updated_at
            end

            fields :hook, :slug, :data, :description, :attempts_succeded, :retries, :progress, :status, :executions, :notifications, :updated_at
          end
        end
      end
    end
  end
end
