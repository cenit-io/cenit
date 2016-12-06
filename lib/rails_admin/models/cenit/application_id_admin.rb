module RailsAdmin
  module Models
    module Cenit
      module ApplicationIdAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 830
            navigation_label 'Administration'
            visible { User.current_super_admin? }
            label 'Application ID'

            register_instance_option(:discard_submit_buttons) { bindings[:object].instance_variable_get(:@registering) }

            configure :name
            configure :registered, :boolean
            configure :redirect_uris, :json_value

            edit do
              field :slug
              field :oauth_name do
                visible { bindings[:object].instance_variable_get(:@registering) }
              end
              field :redirect_uris do
                visible { bindings[:object].instance_variable_get(:@registering) }
              end
            end

            list do
              field :name
              field :registered
              field :tenant
              field :identifier
              field :updated_at
            end

            fields :created_at, :name, :registered, :tenant, :identifier, :created_at, :updated_at
          end
        end

      end
    end
  end
end
