require 'liquid/tags/cenit_basic_tag'

module Liquid
  class Fail < CenitBasicTag

    tag :fail

    def initialize(tag_name, value, tokens)
      super
      @value = value
    end

    def render(context)
      fail Exception, @value
    end
  end
end