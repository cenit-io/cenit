module RailsAdmin
  module Models
    module Setup
      module CrossCollectionPullParameterAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            visible false
            object_label_method { :label }
            configure :properties_locations do
              label 'Properties'
            end
            fields :label, :type, :many, :required, :description, :properties_locations
          end
        end
      end
    end
  end
end
