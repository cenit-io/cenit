module RailsAdmin
  module Models
    module Setup
      module ConnectionAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Connectors'
            navigation_icon 'fa fa-plug'
            weight 201
            object_label_method { :custom_title }

            configure :namespace, :enum_edit

            group :credentials do
              label 'Credentials'
            end

            configure :number, :string do
              label 'Key'
              html_attributes do
                { maxlength: 30, size: 30 }
              end
              group :credentials
              pretty_value do
                (value || '<i class="icon-lock"/>').html_safe
              end
            end

            configure :token, :text do
              html_attributes do
                { cols: '50', rows: '1' }
              end
              group :credentials
              pretty_value do
                (value || '<i class="icon-lock"/>').html_safe
              end
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
            configure :parameters do
              group :parameters
            end
            configure :headers do
              group :parameters
            end
            configure :template_parameters do
              group :parameters
            end

            edit do
              field(:namespace, :enum_edit, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY)
              field(:name, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY)
              field(:url, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY)

              field :number
              field :token
              field :authorization
              field(:authorization_handler, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY)

              field :parameters
              field :headers
              field :template_parameters
            end

            show do
              field :namespace
              field :name
              field :url

              field :number
              field :token
              field :authorization
              field :authorization_handler

              field :parameters
              field :headers
              field :template_parameters

              field :_id
              field :created_at
              field :updated_at
            end

            list do
              field :namespace
              field :name
              field :url
              field :number
              field :token
              field :authorization
              field :updated_at
            end

            fields :namespace, :name, :url, :number, :token, :authorization, :updated_at
          end
        end
      end
    end
  end
end
