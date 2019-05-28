module RailsAdmin
  module Models
    module Setup
      module Oauth2ProviderAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Security'
            weight 312
            parent ::Setup::AuthorizationProvider
            label 'OAuth 2.0 provider'
            register_instance_option :label_navigation do
              'OAuth 2.0'
            end
            object_label_method { :custom_title }

            configure :namespace, :enum_edit

            configure :refresh_token_algorithm do
              visible { bindings[:object].refresh_token_strategy == :custom.to_s }
            end

            edit do
              field :namespace
              field :name
              field :response_type
              field :authorization_endpoint
              field :token_endpoint
              field :token_method
              field :scope_separator
              field :refresh_token_strategy
              field :refresh_token_algorithm
            end

            list do
              field :namespace
              field :name
              field :response_type
              field :authorization_endpoint
              field :token_endpoint
              field :refresh_token_strategy
              field :updated_at
            end

            fields :namespace, :name, :response_type, :authorization_endpoint, :token_endpoint, :token_method, :scope_separator, :refresh_token_strategy, :refresh_token_algorithm, :updated_at
          end
        end
      end
    end
  end
end
