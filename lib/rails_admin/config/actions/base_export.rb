module RailsAdmin
  module Config
    module Actions
      class BaseExport < RailsAdmin::Config::Actions::Translate

        class << self

          def translator_type
            :Export
          end

          def disable_buttons?
            false
          end
        end

        register_instance_option :link_icon do
          'icon-download'
        end

      end
    end
  end
end