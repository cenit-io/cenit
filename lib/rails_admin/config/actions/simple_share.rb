module RailsAdmin
  module Config
    module Actions

      class SimpleShare < RailsAdmin::Config::Actions::BaseShare

        register_instance_option :only do
          [Setup::Collection, Setup::Library, Setup::Translator]
        end

        register_instance_option :member do
          true
        end

      end

    end
  end
end