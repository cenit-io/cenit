module RailsAdmin
  module Models
    module Setup
      module EventAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Workflows'
            navigation_icon 'fa fa-bolt'
            weight 510
            object_label_method { :custom_title }
            visible false

            configure :namespace, :enum_edit

            configure :_type do
              pretty_value do
                value.split('::').last.to_title
              end
            end

            edit do
              field :namespace
              field :name
            end

            show do
              field :namespace
              field :name
              field :_type

              field :_id
              field :created_at
              #field :creator
              field :updated_at
              #field :updater
            end

            list do
              field :namespace
              field :name
              field :_type
              field :updated_at
            end

            fields :namespace, :name, :_type, :updated_at
          end
        end

      end
    end
  end
end
