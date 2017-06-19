module RailsAdmin
  module Models
    module Setup
      module OauthAuthorizationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 332
            label 'OAuth 1.0 authorization'
            register_instance_option :label_navigation do
              'OAuth 1.0'
            end
            object_label_method { :custom_title }
            parent ::Setup::Authorization

            configure :namespace, :enum_edit

            configure :metadata, :json_value

            configure :status do
              pretty_value do
                "<span class=\"label label-#{bindings[:object].status_class}\">#{value.to_s.capitalize}</span>".html_safe
              end
            end

            edit do
              field :namespace
              field :name
              field :client
              field :parameters
              field :template_parameters
              field :metadata
            end

            group :credentials do
              label 'Credentials'
            end

            configure :access_token do
              group :credentials
            end

            configure :token_span do
              group :credentials
            end

            configure :authorized_at do
              group :credentials
            end

            configure :access_token_secret do
              group :credentials
            end

            configure :realm_id do
              group :credentials
            end

            show do
              field :namespace
              field :name
              field :status
              field :client
              field :parameters
              field :template_parameters
              field :metadata
              field :_id

              field :access_token
              field :access_token_secret
              field :realm_id
              field :token_span
              field :authorized_at
            end

            list do
              field :namespace
              field :name
              field :status
              field :client
              field :updated_at
            end

            fields :namespace, :name, :status, :client, :updated_at
          end
        end

      end
    end
  end
end
