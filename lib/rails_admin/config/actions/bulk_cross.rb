module RailsAdmin
  module Config
    module Actions
      class BulkCross < RailsAdmin::Config::Actions::BaseCross

        register_instance_option :only do
          ::Ability::CROSSING_MODELS
        end

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