module RailsAdmin
  module Models
    module Setup
      module CrossCollectionPullParameterAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            visible false
            object_label_method { :label }
            configure :location, :json_value
            edit do
              field :label
              field :property_name
              field :location
            end
            show do
              field :label
              field :property_name
              field :location

              field :created_at
              #field :creator
              field :updated_at
            end
            fields :label, :property_name, :location
          end
        end

      end
    end
  end
end
