module RailsAdmin
  module Config
    module Fields
      module Types
        class Code < RailsAdmin::Config::Fields::Types::CodeMirror

          register_instance_option :html_attributes do
            { cols: '74', rows: '15' }
          end

          register_instance_option :pretty_value do
            action = bindings[:view].instance_variable_get(:@action)
            code =
              begin
                JSON.pretty_generate(value)
              rescue
                value.to_s
              end
            if code && ((absm = bindings[:view].controller.context_abstract_model).nil? ||
               action.listing? ||
               !bindings[:object].is_a?(absm.model_class))
              if (code = code.lines).length > 4
                code = code[0, 4] + ['...']
              end
              code.each_with_index do |line, index|
                if line.length > 50
                  code[index] = "#{line.to(50)}..."
                end
              end
              code = code.join
            end

            js_data = {
              csspath: css_location,
              jspath: js_location,
              options: config,
              locations: assets
            }.to_json.to_s

            code_value = <<-HTML
            <textarea data-richtext="codemirror" data-options=#{js_data}> #{code}
            </textarea>
            HTML

            if action.is_a?(RailsAdmin::Config::Actions::Show) || action.is_a?(RailsAdmin::Config::Actions::RemoteSharedCollection)
              "<form #{(absm.nil? || bindings[:object].is_a?(absm.model_class)) ? 'id="code_show_view"' : 'id="list"'}>#{code_value}</form>"
            else
              code_value
            end.html_safe
          end

          register_instance_option :js_location do
            bindings[:view].asset_path('codemirror.js')
          end

          register_instance_option :css_location do
            bindings[:view].asset_path('codemirror.css')
          end

          register_instance_option :assets do
            {
              mode: bindings[:view].asset_path("codemirror/modes/#{mode_file}.js"),
              theme: bindings[:view].asset_path("codemirror/themes/#{config[:theme]}.css")
            }
          end

          register_instance_option :config do
            default_config.merge(code_config)
          end

          register_instance_option :default_config do
            config = {
              lineNumbers: true,
              theme: (theme = User.current.try(:code_theme)).present? ? theme : (Cenit.default_code_theme || 'monokai')
            }
            config[:readOnly] = [
              RailsAdmin::Config::Actions::Edit,
              RailsAdmin::Config::Actions::New,
              RailsAdmin::Config::Actions::Share,
              RailsAdmin::Config::Actions::Configure,
              RailsAdmin::Config::Actions::Run
            ].exclude?(bindings[:view].instance_variable_get(:@action).class)
            config
          end

          register_instance_option :code_config do
            {
            }
          end

          register_instance_option :mode_file do
            {
              'application/json': 'javascript',
              'application/ld+json': 'javascript',
              'application/x-ejs': 'htmlembedded',
              'application/x-erb': 'htmlembedded',
              'application/xml': 'xml',

              'text/apl': 'apl',
              'text/html': 'xml',
              'text/plain': 'javascript',
              'text/x-ruby': 'ruby',
              'text/x-php': 'php',
              'text/x-python': 'python',
              'text/javascript': 'javascript',
              'text/x-yaml': 'yaml',
              '': 'javascript'
            }[config[:mode].to_s.to_sym] || config[:mode].to_sym
          end
        end
      end
    end
  end
end
