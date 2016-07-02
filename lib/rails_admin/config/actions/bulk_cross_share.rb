module RailsAdmin
  module Config
    module Actions
      class BulkCrossShare < RailsAdmin::Config::Actions::BaseCrossShare

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