module RailsAdmin
  module Models
    module Setup
      module AlgorithmParameterAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            visible false
            fields :name, :type, :many, :required, :default
          end
        end
      end
    end
  end
end
