module RailsAdmin
  module Models
    module Setup
      module ConfigurationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 800
            navigation_label 'Administration'
            visible { User.current_super_admin? }
            label_plural 'Configuration'

            configure :ecommerce_data_types do
              label 'eCommerce Data Types'
            end

            fields :ecommerce_data_types
          end
        end

      end
    end
  end
end
