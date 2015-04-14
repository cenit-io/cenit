module RailsAdmin
  module Config
    module Actions

      class TranslatorUpdate < RailsAdmin::Config::Actions::Translate

        class << self

          def translator_type
            :Update
          end

          def translate(options)
            ((bulk_ids = options[:bulk_ids]) ? options[:model].any_in(id: bulk_ids) : options[:model].all).each do |object|
              options[:translator].run(object: object)
            end
          end
        end

        register_instance_option :except do
          [Setup::Library, Setup::Schema, Setup::Model]
        end

        register_instance_option :link_icon do
          'icon-edit'
        end

      end

    end
  end
end