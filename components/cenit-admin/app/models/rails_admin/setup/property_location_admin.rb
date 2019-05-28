module RailsAdmin
  module Models
    module Setup
      module PropertyLocationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            visible false
            object_label_method { :property_name }
            configure :location, :json_value
            fields :property_name, :location
          end
        end
      end
    end
  end
end
