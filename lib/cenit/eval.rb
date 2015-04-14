module Cenit
  class Eval < Liquid::Tag

    def initialize(tag_name, value, tokens)
      super
      @value = value
    end

    def render(context)
      locals = {}
      context.environments.each { |e| locals.merge!(e) }
      ActionView::Base.new.render inline: @value, type: :ruby, handlers: :ruby, locals: locals.symbolize_keys
    end
  end
end