module RailsAdmin
  module Config
    module Actions

      class BulkShare < RailsAdmin::Config::Actions::BaseShare

        register_instance_option :only do
          [Setup::Library, Setup::Translator, Setup::Algorithm]
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :bulkable? do
          true
        end

      end

    end
  end
end