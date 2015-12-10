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
          transformation = options[:transformation]
          split_style = options[:style].split('.') if options[:style].present?

          format = options[:format] ||= split_style[0].to_sym if split_style[0].present?
          handler = options[:handler] ||= split_style[1].to_sym if split_style[1].present?

          if respond_to?(method = "preprocess_#{handler}_#{format}".to_sym)
            transformation = send(method, transformation, options)
          end

          if handler.present? && metaclass.instance_methods.include?(met = "run_#{handler}".to_sym)
            send(met, options)
          else
            ActionView::Base.new.render inline: transformation, formats: format, type: handler || format, handlers: handler, locals: options
          end
        end

        def run_rabl(options = {})
          Rabl::Renderer.new(options[:transformation], nil, {format: options[:format], locals: options}).render
        end

        def run_haml(options = {})
          Haml::Engine.new(options[:transformation]).render(Object.new, options)
        end

        # def run_prawn(options = {})
        # result = PrawnRails::Engine.try(:new).try :render, inline: options[:transformation], format:  options[:format],  locals: options
        # result
        # end

        def preprocess_erb(transformation, options)
          pattern = /(<%=?)(.*?)(%>)/
          rb = []
          gs = Gensym.new
          marks = []
          res = transformation.gsub(pattern) {
            mark = gs.gen
            marks << mark.to_sym
            rb << Regexp.last_match[2] + " ; #{mark}"
            Regexp.last_match[1] + mark + Regexp.last_match[3]
          }
          rb_src = rb.join("\r\n")
          lcls = options.keys.to_a + marks
          rw = Capataz.rewrite(rb_src, locals: lcls)
          rw = rw.split(/\n/)[(lcls.length)..-1]

          marks.each_with_index do |mark, i|
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
