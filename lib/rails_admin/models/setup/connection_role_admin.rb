module RailsAdmin
  module Models
    module Setup
      module ConnectionRoleAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Connectors'
            weight 210
            label 'Connection Role'
            object_label_method { :custom_title }

            configure :namespace, :enum_edit

            configure :name, :string do
              help 'Required.'
              html_attributes do
                { maxlength: 50, size: 50 }
              end
            end
            configure :webhooks do
              nested_form false
            end
            configure :connections do
              nested_form false
            end
            modal do
              field :namespace
              field :name
              field :webhooks
              field :connections
            end
            show do
              field :namespace
              field :name
              field :webhooks
              field :connections

              field :_id
              field :created_at
              #field :creator
              field :updated_at
              #field :updater
            end

            edit do
              field :namespace
              field :name
              field :webhooks
              field :connections
            end

            fields :namespace, :name, :webhooks, :connections, :updated_at
          end
        end

      end
    end
  end
end
