module RailsAdmin
  module Models
    module Setup
      module CollectionPullParameterAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            visible false
            object_label_method { :label }
            field :label
            field :parameter, :enum do
              enum do
                bindings[:controller].instance_variable_get(:@shared_parameter_enum) || [bindings[:object].parameter]
              end
            end
            edit do
              field :label
              field :parameter
              field :property_name
              field :location, :json_value
            end
            show do
              field :label
              field :parameter

              field :created_at
              #field :creator
              field :updated_at
            end
            list do
              field :label
              field :parameter
              field :updated_at
            end
            fields :label, :parameter
          end
        end

      end
    end
  end
end
