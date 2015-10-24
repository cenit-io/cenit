module RailsAdmin
  module Config
    module Actions
      class SimpleGenerate < RailsAdmin::Config::Actions::BaseGenerate

        register_instance_option :member do
          true
        end

      end
    end
  end
end
