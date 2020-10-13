module RailsAdmin
  module Models
    module Setup
      module BuildInAppAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Compute'
            navigation_icon 'fa fa-laptop'
            weight 420
            object_label_method { :custom_title }
            visible
            configure :identifier
            configure :registered, :boolean

            configure :namespace, :enum_edit

            edit do
              field :namespace do
                read_only true
              end
              field :name do
                read_only true
              end
              field :slug do
                read_only true
              end
              field :tenant
              field :application_parameters
            end
            list do
              field :namespace
              field :name
              field :slug
              field :tenant
              field :updated_at
            end
            fields :namespace, :name, :slug, :identifier, :secret_token, :tenant, :application_parameters
          end
        end
      end
    end
  end
end
