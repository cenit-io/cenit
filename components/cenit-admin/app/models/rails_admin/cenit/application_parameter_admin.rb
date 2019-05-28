module RailsAdmin
  module Models
    module Cenit
      module ApplicationParameterAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            visible false
            navigation_label 'Compute'
            configure :group, :enum_edit

            list do
              field :name
              field :type
              field :many
              field :group
              field :description
              field :updated_at
            end

            fields :name, :type, :many, :group, :description
          end
        end
      end
    end
  end
end
