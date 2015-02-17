require 'builder'

module Setup
  module Transformation
    #ActionView::Template.register_template_handler(:haml, Haml::Plugin)
    class ActionViewTransform < Setup::Transformation::AbstractTransform
      
      class << self
        
        def run(options = {})
          transformation = options[:transformation]
          object = options[:object]
          split_style = options[:style].split('.') if options[:style].present?
        
          format = options[:format] ||=  split_style[0].to_sym if split_style[0].present?
          handler = options[:handler] ||= split_style[1].to_sym if split_style[1].present?
        
          if handler.present? && metaclass.instance_methods.include?( met = "run_#{handler}".to_sym )
            send(met,transformation, object, options)
          else
            view = ActionView::Base.new
            view.try :render, inline: transformation, formats: format, handlers: handler, locals: {object: object}
          end
        end
    
        def run_rabl(options = {})
          format = options[:format] ||= :json
          renderer = Rabl::Renderer.new(options[:transformation], options[:object], { format: format, root: true })
          renderer.render
        end
        
        def run_builder(options = {})
          format = options[:format] ||= :xml          
          eval "xml = ::Builder::XmlMarkup.new(:indent => 2);" +
            #"self.output_buffer = xml.target!;" +
            options[:transformation] +
            ";xml.target!;"
        end
        
        def run_haml(options = {})
          format = options[:format] ||= :html          
          eval Haml::Engine.new(options[:transformation]).compiler.precompiled_with_ambles([])
        end

        def types
          [:Export]
        end
        
      end
    end
  end
end