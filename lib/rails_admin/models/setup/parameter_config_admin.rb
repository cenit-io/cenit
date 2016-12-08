module RailsAdmin
  module Models
    module Setup
      module ParameterConfigAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Configuration'
            label 'Parameter'
            weight 760

            configure :parent_model, :model
            configure :parent, :record

            edit do
              field :parent_model do
                read_only true
                help ''
              end
              field :parent do
                read_only true
                help ''
              end
              field :location do
                read_only true
                help ''
              end
              field :name do
                read_only true
                help ''
              end
              field :value
            end

            fields :parent_model, :parent, :location, :name, :value, :updated_at

            show_in_dashboard false
          end
        end

      end
    end
  end
end
