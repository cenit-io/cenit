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
            object_label_method :id

            group :data_types do
              label 'Data Types'
            end

            configure :ecommerce_data_types do
              group :data_types
              label 'eCommerce Data Types'
            end

            configure :email_data_type do
              group :data_types
              label 'Email Data Type'
            end

            group :home_sections do
              label 'Home Sections'
            end

            configure :social_networks, :json_value do
              group :home_sections
              label 'Social Networks'
              help 'Defines your social networks links'
              visible { ::Cenit.host == ::Cenit.homepage }
            end

            configure :home_services_menu, :json_value do
              group :home_sections
              label 'Home Service Menu'
              help 'Defines your home services paths'
              visible { ::Cenit.host == ::Cenit.homepage }
            end

            configure :home_services, :json_value do
              group :home_sections
              label 'Home Services'
              help 'Describe your home services'
              visible { ::Cenit.host == ::Cenit.homepage }
            end

            configure :home_explore_menu, :json_value do
              group :home_sections
              label 'Home Explore Menu'
              help 'Defines your home explore paths'
              visible { ::Cenit.host == ::Cenit.homepage }
            end

            configure :home_integrations, :json_value do
              group :home_sections
              label 'Home Integrations'
              help 'Defines your home integrations'
              visible { ::Cenit.host == ::Cenit.homepage }
            end

            configure :home_features, :json_value do
              group :home_sections
              label 'Home Features'
              help 'Describe your home features'
              visible { ::Cenit.host == ::Cenit.homepage }
            end
          end
        end

      end
    end
  end
end
