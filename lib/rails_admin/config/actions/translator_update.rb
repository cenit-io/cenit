module RailsAdmin
  module Config
    module Actions

      class TranslatorUpdate < RailsAdmin::Config::Actions::Translate

        class << self

          def translator_type
            :Update
          end
        end

        register_instance_option :except do
          [Setup::Library, Setup::Schema, Setup::DataType]
        end

        register_instance_option :link_icon do
          'icon-edit'
        end

      end

    end
  end
end