module RailsAdmin
  module Config
    module Actions
      class SimpleDeleteDataType < RailsAdmin::Config::Actions::BaseDeleteDataType

        register_instance_option :member do
          true
        end

        register_instance_option :visible? do
          authorized? &&
            (!(dt = bindings[:object]).is_a?(Setup::CenitDataType) || dt.origin == :tmp || dt.build_in.nil?)
        end
      end
    end
  end
end