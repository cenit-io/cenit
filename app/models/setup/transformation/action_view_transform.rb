require 'builder'

module Setup
  module Transformation
    class ActionViewTransform < Setup::Transformation::AbstractTransform
      class << self
        
        def run(transformation, object, options = {})
          split_style = options[:style].split('.') if options[:style].present?
        
          format = options[:format] ||=  split_style[0].to_sym if split_style[0].present?
          handler = options[:handler] ||= split_style[1].to_sym if split_style[1].present?
        
          if handler.present? && metaclass.instance_methods.include?( met = "run_#{handler}".to_sym )
            transformation = send(met,transformation, object, options)
          else
            view = ActionView::Base.new
            view.try :render, inline: transformation, formats: format, handlers: handler, locals: {object: object}
          end
        end
    
        def run_rabl(transformation, object, options = {})
          format = options[:format] ||= :json
          renderer = Rabl::Renderer.new(transformation, object, { format: format, root: true })
          renderer.render
        end
    
        def run_builder(transformation, object, options = {})
          xml = Builder::XmlMarkup.new
          eval(transformation)
        end
        
      end
    end
  end
end