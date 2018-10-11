module RailsAdmin
  module Config
    module Actions
      class SimpleExpand < RailsAdmin::Config::Actions::BaseExpand

        register_instance_option :visible? do
          authorized? && bindings[:object].is_a?(Setup::JsonDataType)
        end

        register_instance_option :member do
          true
        end

      end
    end
  end
end
