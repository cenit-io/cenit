module RailsAdmin
  module Models
    module Setup
      module DataTypeConfigAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Configuration'
            navigation_icon 'fa fa-wrench'
            label 'Data Type Config'
            visible true
            weight 710

            configure :data_type do
              read_only { !bindings[:object].new_record? }
              contextual_association_scope do
                taken_ids = abstract_model.all.collect(&:data_type_id)
                proc { |scope| scope.and(:id.nin => taken_ids) }
              end
            end

            configure :trace_on_default, :toggle_boolean
            configure :navigation_link, :toggle_boolean
            configure :chart_rendering, :toggle_boolean

            edit do
              field :data_type
              field :slug
              field :trace_on_default do
                visible do
                  bindings[:object].tracing_option_available?
                end
              end
              field :navigation_link do
                visible do
                  (obj = bindings[:object]).data_type.nil? || !obj.data_type.is_a?(::Setup::CenitDataType)
                end
              end
              field :chart_rendering
            end

            show do
              field :data_type
              field :slug
              field :trace_on_default do
                visible do
                  bindings[:object].tracing_option_available?
                end
              end
              field :navigation_link
              field :chart_rendering
            end

            fields :data_type, :slug, :trace_on_default, :navigation_link, :chart_rendering, :updated_at

            show_in_dashboard false
          end
        end
      end
    end
  end
end
