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
              read_only true
            end
            fields :data_type, :slug, :navigation_link, :chart_rendering, :updated_at

            show_in_dashboard false
          end
        end

      end
    end
  end
end
