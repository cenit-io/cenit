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
            fields :label, :description, :property_name, :location
          end
        end

      end
    end
  end
end
