module RailsAdmin
  module Config
    module Actions
      class Convert < RailsAdmin::Config::Actions::Translate

        register_instance_option :collection do
          true
        end

        register_instance_option :bulkable? do
          true
        end

        register_instance_option :bulk_processable? do
          true
        end

        class << self

          def translator_type
            :Conversion
          end
        end

        register_instance_option :link_icon do
          'icon-cog'
        end

      end
    end
  end
end