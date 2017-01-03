module RailsAdmin
  module Models
    module Setup
      module TaskExecutionAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            visible false
            navigation_label 'Monitors'
            weight 600
            object_label_method { :label }

            show_in_dashboard false
            configure :created_at

            configure :attachment, :storage_file

            configure :time_span, :time_span

            list do
              field :created_at
              field :started_at
              field :time_span
              field :status
              field :attachment
              field :task
            end
          end
        end

      end
    end
  end
end
