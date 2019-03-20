module RailsAdmin
  module Config
    module Actions
      class TranslatorUpdate < RailsAdmin::Config::Actions::Translate

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
            :Update
          end
        end

        register_instance_option :except do
          [Setup::DataType]
        end

        register_instance_option :link_icon do
          'icon-edit'
        end

      end
    end
  end
end