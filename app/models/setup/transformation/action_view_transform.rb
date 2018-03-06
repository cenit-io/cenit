require 'builder'

module Setup
  module Transformation
    class ActionViewTransform < Setup::Transformation::AbstractTransform

      class Gensym
        def initialize
          @val = 1
        end

        def gen
          r = "____#{@val}"
          @val += 1
          r
        end
      end

      class << self

        def run(options = {})
          code = options[:code]
          split_style = options[:style].split('.') if options[:style].present?

          format = options[:format] ||= split_style[0].to_sym if split_style[0].present?
          handler = options[:handler] ||= split_style[1].to_sym if split_style[1].present?

          if respond_to?(method = "preprocess_#{handler}_#{format}".to_sym)
            code = send(method, code, options)
          end

          if handler.present? && metaclass.instance_methods.include?(met = "run_#{handler}".to_sym)
            send(met, options)
          else
            if options[:control]
              options[:control].view ||= ActionView::Base.new(nil, {}, options[:control].controller)
            end

            av = options[:control].try(:view) || ActionView::Base.new
            av.render inline: code, formats: format, type: handler || format, handlers: handler, locals: options
          end
        end

        def run_rabl(options = {})
          Rabl::Renderer.new(options[:code], nil, { format: options[:format], locals: options }).render
        end

        def run_haml(options = {})
          Haml::Engine.new(options[:code]).render(Object.new, options)
        end

        def preprocess_erb(code, options)
          return code if Capataz.disable?
          pattern = /(<%=?)(.*?)(%>)/m
          rb = []
          gs = Gensym.new
          marks = []
          res = code.gsub(pattern) do
            match_1 = Regexp.last_match[1]
            match_2 = Regexp.last_match[2]
            match_3 = Regexp.last_match[3]
            mark = gs.gen
            marks << mark.to_sym
            rb << match_2.strip.gsub(/\n/, ';').squeeze(';') + " ; #{mark}"
            match_1 + mark + match_3
          end
          rb_src = rb.join("\n")
          lcls = options.keys.to_a + marks
          rw = Capataz.rewrite(rb_src, locals: lcls)
          rw = rw.split(/\n/)[(lcls.length)..-1]

          marks.to_enum.with_index.reverse_each do |mark, i|
            res = res.gsub(mark.to_s, rw[i][0..(-(mark.to_s.length + 3))])
          end

          res
        end

        alias_method :preprocess_erb_html, :preprocess_erb

        alias_method :preprocess_erb_js, :preprocess_erb

      end
    end
  end
end
