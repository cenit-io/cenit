module RailsAdmin
  module Config
    module Actions
      class SimpleDeleteDataType < RailsAdmin::Config::Actions::BaseDeleteDataType

        register_instance_option :member do
          true
        end
      end
    end
  end
end