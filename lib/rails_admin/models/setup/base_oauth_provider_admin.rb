module RailsAdmin
  module Models
    module Setup
      module BaseOauthProviderAdmin
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
              field :response_type
              field :authorization_endpoint
              field :token_endpoint
              field :token_method
              field :updated_at
            end

            fields :namespace, :name, :_type, :response_type, :authorization_endpoint, :token_endpoint, :token_method
          end
        end

      end
    end
  end
end
