module RailsAdmin
  module Models
    module Setup
      module ParameterAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Configuration'
            weight 760
            visible true
            object_label_method { :to_s }
            configure :metadata, :json_value
            configure :parent_model, :model do
              visible do
                (model_config = bindings[:controller].instance_variable_get(:@model_config)) &&
                  model_config.abstract_model.model == ::Setup::Parameter
              end
              read_only true
              help ''
              visible_parent_lookup true
            end
            configure :parent, :record do
              visible do
                (model_config = bindings[:controller].instance_variable_get(:@model_config)) &&
                  model_config.abstract_model.model == ::Setup::Parameter
              end
              read_only true
              help ''
            end
            configure :key do
              label 'Name'
            end
            configure :description
            configure :metadata
            configure :updated_at
            edit do
              field :parent_model, :model do
                visible do
                  bindings[:controller].instance_variable_get(:@model_config).abstract_model.model == ::Setup::Parameter
                end
                read_only true
                help ''
                visible_parent_lookup true
              end
              field :parent, :record do
                visible do
                  bindings[:controller].instance_variable_get(:@model_config).abstract_model.model == ::Setup::Parameter
                end
                read_only true
                help ''
              end
              field :key
              field :value, :text
              field :description
              field :metadata
            end
            fields :parent_model, :parent, :key, :value, :description, :metadata, :updated_at
          end
        end
      end
    end
  end
end
