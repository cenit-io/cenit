module RailsAdmin
  module Models
    module Setup
      module GenericAuthorizationProviderAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Security'
            navigation_icon 'fa fa-wrench'
            weight 310
            object_label_method { :custom_title }
            label 'Generic provider'
            register_instance_option :label_navigation do
              'Generic'
            end

            configure :namespace, :enum_edit

            list do
              field :namespace
              field :name
              field :authorization_endpoint
            end

            fields :namespace, :name, :authorization_endpoint
          end
        end

      end
    end
  end
end
