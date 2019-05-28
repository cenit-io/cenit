module RailsAdmin
  module Models
    module Setup
      module ResourceAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Connectors'
            navigation_icon 'fa fa-archive'
            weight 215
            label 'Resource'
            object_label_method { :custom_title }

            configure :namespace, :enum_edit

            configure :name, :string do
              help 'Required.'
              html_attributes do
                { maxlength: 50, size: 50 }
              end
            end

            configure :path, :string do
              help 'Required. Path of the resource relative to connection URL.'
              html_attributes do
                { maxlength: 255, size: 100 }
              end
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

            show do
              field :namespace
              field :name
              field :path
              field :description
              field :operations
              field :headers
              field :parameters
              field :template_parameters

              field :_id
              field :created_at
              #field :creator
              field :updated_at
              #field :updater
            end

            edit do
              field :namespace, :enum_edit, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :name, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :path, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :description, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :operations, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :parameters
              field :headers
              field :template_parameters
            end

            fields :namespace, :name, :path, :description, :operations, :updated_at

            filter_query_fields :namespace, :name, :path
          end
        end
      end
    end
  end
end
