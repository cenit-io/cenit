module RailsAdmin
  module Config
    module Fields
      module Types
        class Code < RailsAdmin::Config::Fields::Types::CodeMirror

          register_instance_option :js_location do
            bindings[:view].asset_path('codemirror.js')
          end

          register_instance_option :css_location do
            bindings[:view].asset_path('codemirror.css')
          end

          register_instance_option :assets do
            {
              mode: bindings[:view].asset_path("codemirror/modes/#{mode_file}.js"),
              theme: bindings[:view].asset_path("codemirror/themes/#{config[:theme]}.css"),
            }
          end

          register_instance_option :config do
            default_config.merge(code_config)
          end

          register_instance_option :default_config do
            {
              lineNumbers: true,
              theme: 'night'
            }
          end

          register_instance_option :code_config do
            {
              lineNumbers: true,
              theme: 'night'
            }
          end

          register_instance_option :mode_file do
            {
              'application/json': 'javascript',
              'application/ld+json': 'javascript',
              'text/x-ruby': 'ruby',
              'application/xml': 'xml',
              'text/html': 'xml'
            }[config[:mode].to_sym]
          end
        end
      end
    end
  end
end
