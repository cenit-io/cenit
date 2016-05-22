module Haml
  module Filters
    module Base

      # This should be overridden when a filter needs to have access to the Haml
      # evaluation context. Rather than applying a filter to a string at
      # compile-time, \{#compile} uses the {Haml::Compiler} instance to compile
      # the string to Ruby code that will be executed in the context of the
      # active Haml template.
      #
      # Warning: the {Haml::Compiler} interface is neither well-documented
      # nor guaranteed to be stable.
      # If you want to make use of it, you'll probably need to look at the
      # source code and should test your filter when upgrading to new Haml
      # versions.
      #
      # @param compiler [Haml::Compiler] The compiler instance
      # @param text [String] The text of the filter
      # @raise [Haml::Error] if none of \{#compile}, \{#render}, and
      #   \{#render_with_options} are overridden
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
find_and_preserve(#{filter.inspect}.render_with_options(#{text}, try('_hamlout').try('options') || {:format => :html5} ))
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