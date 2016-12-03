module RailsAdmin
  module Models
    module Setup
      module ResourceAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            visible { Account.current_super_admin? }
            navigation_label 'Connectors'
            weight 215
            label 'Resource'
            object_label_method { :custom_title }

            configure :name, :string do
              help 'Requiered.'
              html_attributes do
                { maxlength: 50, size: 50 }
              end
            end

            configure :path, :string do
              help 'Requiered. Path of the resource relative to connection URL.'
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

              field :_id
              field :created_at
              #field :creator
              field :updated_at
              #field :updater
            end

            edit do
              field :namespace, :enum_edit, &RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_non_editable
              field :name, &RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_non_editable
              field :path, &RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_non_editable
              field :description, &RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_non_editable
              field :operations, &RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_non_editable
              field :parameters
              field :headers
              field :template_parameters
            end

            fields :namespace, :name, :path, :description, :operations, :updated_at
          end
        end

      end
    end
  end
end
