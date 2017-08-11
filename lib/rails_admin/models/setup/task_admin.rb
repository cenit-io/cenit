module RailsAdmin
  module Models
    module Setup
      module TaskAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Monitors'
            visible true
            weight 610
            object_label_method { :to_s }
            show_in_dashboard false


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

            fields :_type, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :updated_at
          end
        end

      end
    end
  end
end
