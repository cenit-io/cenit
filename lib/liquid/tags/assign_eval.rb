require 'liquid/tags/assign'

module Liquid
  class AssignEval < Assign

    def initialize(tag_name, markup, options)
      super
      @from = Eval.parse(:eval, @from.raw, [], options)
    end
  end

  Template.register_tag('assign_eval'.freeze, AssignEval)
end