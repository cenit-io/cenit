
require 'liquid/tags/cenit_basic_tag'

module Liquid
  class Eval < CenitBasicTag

    tag :eval

    def initialize(tag_name, value, tokens)
      super
      @value = value
    end

    def render(context)
      locals = {}
      context.environments.each { |e| locals.merge!(e) }
      ActionView::Base.new.render inline: Capataz.rewrite(@value, locals: locals.keys), type: :ruby, handlers: :ruby, locals: locals.symbolize_keys
    end
  end
end