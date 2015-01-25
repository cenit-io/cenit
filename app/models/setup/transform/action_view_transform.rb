require 'active_support/builder' unless defined?(Builder)
require 'builder'

module Setup
  module Transform
    class ActionViewTransform < Setup::Transform::AbstractTransform
      
      def self.run(transformation, document, options = {})
        split_style = options[:style].split('.') if options[:style].present?
        
        format = options[:format] 
        format ||= split_style[0].to_sym if split_style[0].present?
        
        handler = options[:handler]
        handler ||= split_style[1].to_sym if split_style[1].present?
        xml = Builder::XmlMarkup.new
        view = ActionView::Base.new
        
        transformation = eval(transformation) if handler == :builder
       # byebug
        view.try :render, inline: transformation, formats: format, handlers: handler, locals: {object: document}
      end

    end
  end
end