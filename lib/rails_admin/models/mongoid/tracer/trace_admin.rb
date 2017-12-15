module RailsAdmin
  module Models
    module Mongoid
      module Tracer
        module TraceAdmin
          extend ActiveSupport::Concern

          included do
            rails_admin do
              navigation_label 'Monitors'
              navigation_icon 'fa fa-code-fork'
              object_label_method :label
              weight 600
              visible true
              show_in_dashboard false

              api_path "#{::Setup.to_s.underscore}/trace"

              configure :target_id, :json_value do
                label 'Target ID'
              end

              configure :target_model, :model do
                visible do
                  bindings[:controller].action_name == 'index'
                end
              end

              configure :target, :record do
                visible do
                  bindings[:controller].action_name != 'member_trace_index'
                end
              end

              configure :action do
                pretty_value do
                  if (msg = bindings[:object].message)
                    "#{msg} (#{bindings[:object].action})"
                  else
                    value.to_s.to_title
                  end
                end
              end

              configure :attributes_trace, :json_value

              fields :target_model, :target, :action, :attributes_trace, :created_at

              filter_fields :target_id, :action, :attributes_trace, :created_at
            end
          end

        end
      end
    end
  end
end
