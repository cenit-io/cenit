module RailsAdmin
  module Models
    module Setup
      module FlowConfigAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Configuration'
            navigation_icon 'fa fa-wrench'
            label 'Flow Config'
            weight 720
            visible true
            configure :flow do
              read_only { !bindings[:object].new_record? }
              contextual_association_scope do
                taken_ids = abstract_model.all.collect(&:flow_id)
                proc { |scope| scope.and(:id.nin => taken_ids) }
              end
            end

            configure :active, :toggle_boolean

            configure :notify_request, :toggle_boolean

            configure :notify_response, :toggle_boolean

            configure :discard_events, :toggle_boolean

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
