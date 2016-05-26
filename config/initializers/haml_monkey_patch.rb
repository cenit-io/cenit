module Haml
  module Helpers
    def find_and_preserve_with_tag(input = nil, haml_buffer = haml_buffer, &block)
      tags = []
      tags = haml_buffer.options[:preserve] if haml_buffer && haml_buffer.options.present?
      return preserve(input) if block.nil? && tags.nil?
      find_and_preserve_without_tag(input, tags, &block)
    end
    alias_method_chain :find_and_preserve, :tag
  end
  
  module Filters
    module Base
      def compile(compiler, text)
        filter = self
        compiler.instance_eval do
          if contains_interpolation?(text)
            return if options[:suppress_eval]

            text = unescape_interpolation(text).gsub(/(\\+)n/) do |s|
              escapes = $1.size
              next s if escapes % 2 == 0
              ("\\" * (escapes - 1)) + "\n"
            end
            text = "\n" + text.sub(/\n"\Z/, "\\n\"")
            push_script <<RUBY.rstrip, :escape_html => false
find_and_preserve(#{filter.inspect}.render_with_options(#{text}, try(:options) || {format: :html5}  ))
RUBY
            return
          end

          rendered = Haml::Helpers::find_and_preserve(filter.render_with_options(text, compiler.options), compiler.options[:preserve])

          if options[:ugly]
            push_text(rendered.rstrip)
          else
            push_text(rendered.rstrip.gsub("\n", "\n#{'  ' * @output_tabs}"))
          end
        end
      end
    end
  end

end