module RailsAdmin
  module Models
    module Setup
      module ApplicationAdmin
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
              field :namespace
              field :name
              field :slug
              field :actions
              field :application_parameters
            end
            list do
              field :namespace
              field :name
              field :slug
              field :registered
              field :actions
              field :application_parameters
              field :updated_at
            end
            fields :namespace, :name, :slug, :identifier, :secret_token, :registered, :actions, :application_parameters
          end
        end

      end
    end
  end
end
