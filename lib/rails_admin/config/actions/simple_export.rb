module RailsAdmin
  module Config
    module Actions

      class SimpleExport < RailsAdmin::Config::Actions::BaseExport

        register_instance_option :member do
          true
        end

      end

    end
  end
end