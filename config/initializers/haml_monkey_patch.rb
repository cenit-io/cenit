module Haml
  module Helpers

    def find_and_preserve(input = nil, haml_buffer = haml_buffer, &block)
      tags = nil
      tags = haml_buffer.options[:preserve] if haml_buffer && haml_buffer.options.present?
      return find_and_preserve(capture_haml(&block), input || tags) if block
      return preserve(input) if tags.nil?
      re = /<(#{tags.map(&Regexp.method(:escape)).join('|')})([^>]*)>(.*?)(<\/\1>)/im 
      input.to_s.gsub(re) do |s|
        s =~ re # Can't rely on $1, etc. existing since Rails' SafeBuffer#gsub is incompatible
        "<#{$1}#{$2}>#{preserve($3)}</#{$1}>"
      end
    end
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
            # We need to add a newline at the beginning to get the
            # filter lines to line up (since the Haml filter contains
            # a line that doesn't show up in the source, namely the
            # filter name). Then we need to escape the trailing
            # newline so that the whole filter block doesn't take up
            # too many.
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