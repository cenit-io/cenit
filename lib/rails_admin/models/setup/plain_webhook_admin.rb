module RailsAdmin
  module Models
    module Setup
      module PlainWebhookAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Connectors'
            navigation_icon 'fa fa-anchor'
            label 'Webhook'
            weight 515
            object_label_method { :custom_title }

            configure :metadata, :json_value

            group :credentials do
              label 'Credentials'
            end

            configure :authorization do
              group :credentials
              inline_edit false
            end

            configure :authorization_handler do
              group :credentials
            end

            group :parameters do
              label 'Parameters & Headers'
            end

            configure :path, :string do
              help 'Required. Path of the webhook relative to connection URL.'
              html_attributes do
                { maxlength: 255, size: 100 }
              end
            end

            configure :parameters do
              group :parameters
            end

            configure :headers do
              group :parameters
            end

            configure :template_parameters do
              group :parameters
            end

            configure :namespace, :enum_edit

            edit do
              field(:namespace, :enum_edit, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY)
              field(:name, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY)
              field(:path, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY)
              field(:method, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY)
              field(:description, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY)
              field(:metadata, :json_value, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY)

              field :authorization
              field(:authorization_handler, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY)

              field :parameters
              field :headers
              field :template_parameters
            end

            show do
              field :namespace
              field :name
              field :path
              field :method
              field :description
              field :metadata, :json_value

              field :authorization
              field :authorization_handler

              field :parameters
              field :headers
              field :template_parameters

              field :_id
              field :created_at
              #field :creator
              field :updated_at
              #field :updater
            end

            fields :namespace, :name, :path, :method, :description, :authorization, :updated_at

            filter_query_fields :namespace, :name, :path
          end
        end
      end
    end
  end
end
