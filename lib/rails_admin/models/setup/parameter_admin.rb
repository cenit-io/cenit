module RailsAdmin
  module Models
    module Setup
      module ParameterAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            visible false
            object_label_method { :to_s }
            configure :metadata, :json_value
            configure :value
            edit do
              field :name
              field :value
              field :description
              field :metadata
            end
            list do
              field :name
              field :value
              field :description
              field :metadata
              field :updated_at
            end
          end
        end

      end
    end
  end
end
