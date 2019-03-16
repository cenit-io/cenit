module RailsAdmin
  module Models
    module Setup
      module Oauth2AuthorizationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Security'
            weight 333
            label 'OAuth 2.0 Authorization'
            register_instance_option :label_navigation do
              'OAuth 2.0'
            end
            object_label_method { :custom_title }
            parent ::Setup::Authorization
            hierarchy_selectable true

            configure :namespace, :enum_edit

            configure :metadata, :json_value

            configure :status do
              pretty_value do
                "<span class=\"label label-#{bindings[:object].status_class}\">#{value.to_s.capitalize}</span>".html_safe
              end
            end

            configure :expires_in, :time_span do
              negative_pretty_value 'Expired'
            end

            edit do
              field :namespace
              field :name
              field :client
              field :scopes do
                visible { bindings[:object].ready_to_save? }
                associated_collection_scope do
                  limit = (associated_collection_cache_all ? nil : 30)
                  provider_id = (obj = bindings[:object]) && (obj = obj.provider) && obj.id
                  Proc.new do |scope|
                    if provider_id
                      scope.where(provider_id: provider_id)
                    else
                      scope
                    end.limit(limit)
                  end
                end
              end
              field :parameters do
                visible { bindings[:object].ready_to_save? }
              end
              field :template_parameters do
                visible { bindings[:object].ready_to_save? }
              end
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

            configure :refresh_token do
              group :credentials
            end

            configure :token_type do
              group :credentials
            end

            show do
              field :namespace
              field :name
              field :status
              field :client
              field :scopes
              field :parameters
              field :template_parameters
              field :metadata
              field :_id

              field :expires_in

              field :id_token
              field :token_type
              field :access_token
              field :token_span
              field :authorized_at
              field :refresh_token

              field :_id
            end

            fields :namespace, :name, :status, :client, :scopes, :updated_at
          end
        end
      end
    end
  end
end
