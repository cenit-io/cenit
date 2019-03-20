module RailsAdmin
  module Config
    module Actions
      class BulkExport < RailsAdmin::Config::Actions::BaseExport

        register_instance_option :collection do
          true
        end

        register_instance_option :bulkable? do
          true
        end

        register_instance_option :bulk_processable? do
          true
        end

        def key
          :export
        end
      end
    end
  end
end