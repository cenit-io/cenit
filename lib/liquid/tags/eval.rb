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
      Cenit::BundlerInterpreter.run_code(@value, locals, linking_algorithms: false)
    end
  end
end