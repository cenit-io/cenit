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
            file_name = "#{options[:data_type].title.underscore}_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}"
            if (translator = options[:translator]).file_extension.present?
              file_name += ".#{translator.file_extension}"
            end
            options[:controller].send_data(options[:translation], filename: file_name, type: translator.mime_type || 'application/octet-stream')
            #options[:controller].render plain: options[:translation]
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