module RailsAdmin
  module Models
    module Setup
      module FlowConfigAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Configuration'
            label 'Flow Config'
            weight 720
            visible true
            configure :flow do
              read_only true
            end
            configure :auto_retry do
              help ''
            end
            fields :flow, :active, :auto_retry, :notify_request, :notify_response, :discard_events

            show_in_dashboard false
          end
        end

      end
    end
  end
end
