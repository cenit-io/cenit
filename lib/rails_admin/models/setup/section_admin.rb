module RailsAdmin
  module Models
    module Setup
      module SectionAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            visible { ::User.current_super_admin? }
            navigation_label 'Connectors'
            weight 210
            label 'Section'
            object_label_method { :custom_title }
            visible false

            configure :name, :string do
              help 'Required.'
              html_attributes do
                { maxlength: 50, size: 50 }
              end
            end
            configure :connection do
              nested_form false
            end
            show do
              field :namespace
              field :name
              field :description
              field :connection
              field :resources
              field :representations
              field :_id
              field :created_at
              #field :creator
              field :updated_at
              #field :updater
            end

            edit do
              field :namespace, :enum_edit
              field :name
              field(:description, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY)
              field :connection
              field :resources
              field :representations
            end

            fields :namespace, :name, :description, :resources, :connection, :updated_at
          end
        end

      end
    end
  end
end
