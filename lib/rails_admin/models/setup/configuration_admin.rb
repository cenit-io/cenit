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

            group :data_types do
              label 'Data Types'
              active false
            end

            configure :ecommerce_data_types do
              group :data_types
              label 'eCommerce Data Types'
            end

            configure :email_data_type do
              group :data_types
              label 'Email Data Types'
            end

            group :home_sections do
              label 'Home Sections'
              active false
            end

            configure :social_networks, :json_value do
              group :home_sections
              label 'Social Networks'
              help 'Defines your social networks links'
            end

            configure :home_services_menu, :json_value do
              group :home_sections
              label 'Home Service Menu'
              help 'Defines your home services paths'
            end

            configure :home_services, :json_value do
              group :home_sections
              label 'Home Services'
              help 'Describe your home services'
            end

            configure :home_explore_menu, :json_value do
              group :home_sections
              label 'Home Explore Menu'
              help 'Defines your home explore paths'
            end

            configure :home_integrations, :json_value do
              group :home_sections
              label 'Home Integrations'
              help 'Defines your home integrations'
            end

            configure :home_features, :json_value do
              group :home_sections
              label 'Home Features'
              help 'Describe your home features'
            end
          end
        end

      end
    end
  end
end
