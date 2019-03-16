module RailsAdmin
  module Models
    module Setup
      module AuthorizationProviderAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Security'
            navigation_icon 'fa fa-wrench'
            weight 310
            object_label_method { :custom_title }
            label 'Provider'

            configure :_type do
              pretty_value do
                value.split('::').last.to_title
              end
            end

            configure :namespace, :enum_edit

            list do
              field :namespace
              field :name
              field :_type
              field :authorization_endpoint
            end

            fields :namespace, :name, :_type, :authorization_endpoint
          end
        end
      end
    end
  end
end
