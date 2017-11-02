module RailsAdmin
  module Models
    module Setup
      module DataTypeConfigAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Configuration'
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

            fields :data_type, :slug, :navigation_link, :chart_rendering, :track_default_history, :updated_at

            show_in_dashboard false
          end
        end

      end
    end
  end
end
