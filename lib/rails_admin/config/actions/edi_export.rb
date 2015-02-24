module RailsAdmin
  module Config
    module Actions

      class EdiExport < RailsAdmin::Config::Actions::Translate

        class << self

          def translator_type
            :Export
          end

          def translate(options)
            options[:translator].run(object_ids: options[:bulk_ids], source_data_type: options[:data_type])
          end

          def done(options)
            options[:controller].render plain: options[:translation]
          end
        end

        register_instance_option :link_icon do
          'icon-download'
        end

      end

    end
  end
end