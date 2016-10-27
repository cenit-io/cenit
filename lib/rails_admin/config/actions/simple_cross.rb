module RailsAdmin
  module Config
    module Actions
      class SimpleCross < RailsAdmin::Config::Actions::BaseCross

        register_instance_option :member do
          true
        end

      end
    end
  end
end