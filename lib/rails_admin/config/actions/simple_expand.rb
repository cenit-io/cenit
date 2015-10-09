module RailsAdmin
  module Config
    module Actions
      class SimpleExpand < RailsAdmin::Config::Actions::BaseExpand

        register_instance_option :only do
          [Setup::DataType, Setup::SchemaDataType]
        end

        register_instance_option :visible? do
          authorized? && bindings[:object].is_a?(Setup::SchemaDataType)
        end

        register_instance_option :member do
          true
        end

      end
    end
  end
end
