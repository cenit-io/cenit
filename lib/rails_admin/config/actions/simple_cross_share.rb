module RailsAdmin
  module Config
    module Actions
      class SimpleCrossShare < RailsAdmin::Config::Actions::BaseCrossShare

        register_instance_option :member do
          true
        end

      end
    end
  end
end