module RailsAdmin
  module Config
    module Actions

      class Convert < RailsAdmin::Config::Actions::Translate

        class << self

          def translator_type
            :Conversion
          end
        end

        register_instance_option :except do
          [Setup::Library, Setup::Schema, Setup::DataType]
        end

        register_instance_option :link_icon do
          'icon-cog'
        end

      end

    end
  end
end