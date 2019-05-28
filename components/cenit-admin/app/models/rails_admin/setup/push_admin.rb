module RailsAdmin
  module Models
    module Setup
      module PushAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Monitors'
            visible false
            object_label_method { :to_s }

            configure :attempts_succeded, :text do
              label 'Attempts/Succedded'
            end

            configure :source_collection do
              list_fields do
                %w(title image name tags)
              end
            end

            configure :shared_collection do
              list_fields do
                %w(title image name tags)
              end
            end

            edit do
              field :description
              field :auto_retry
            end

            list do
              field :source_collection
              field :shared_collection
              field :description
              field :scheduler
              field :attempts_succeded
              field :retries
              field :progress
              field :status
              field :updated_at
            end

            fields :source_collection, :shared_collection, :description, :attempts_succeded, :retries, :progress, :status, :executions, :notifications, :updated_at
          end
        end
      end
    end
  end
end
