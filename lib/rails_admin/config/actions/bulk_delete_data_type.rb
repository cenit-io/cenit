module RailsAdmin
  module Config
    module Actions
      class BulkDeleteDataType < RailsAdmin::Config::Actions::BaseDeleteDataType

        register_instance_option :collection do
          true
        end

        register_instance_option :bulkable? do
          true
        end

        register_instance_option :bulk_processable? do
          true
        end
      end
    end
  end
end