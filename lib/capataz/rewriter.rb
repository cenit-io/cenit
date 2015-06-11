module Capataz
  class Rewriter < Parser::Rewriter

    def initialize(options = {})
      @options = {errors: []}.merge(options)
      @capatized_nodes = Set.new
    end

    def rewrite(source_buffer, ast)
      @options[:errors].clear
      @capatized_nodes.clear
      @source_rewriter = Capataz::SourceRewriter.new(source_buffer)

      process(ast)

      @source_rewriter.preprocess
      @source_rewriter.process
    end

    def on_send(node)
      super
      report_error("invoking method #{node.children[1]} is not allowed") unless Capataz.allows_invocation_of(node.children[1])
      if left = node.children[0]
        capatize(left) if left.type != :send
      else
         insert_before(node.location.expression, '::Capataz.handle(self).') if node.type == :send
      end
      i = 2
      while i < node.children.length
        capatize(node.children[i])
        i += 1
      end
    end

    def on_casgn(node)
      report_error('can not define (or override) constants') unless Capataz.can_declare?(:constant)
      super
      capatize(node.children[2])
    end

    def on_lvasgn(node)
      super
      capatize(node.children[1])
    end

    def on_class(node)
      report_error('can not define classes') unless Capataz.can_declare?(:class)
      super
    end

    def on_module(node)
      report_error('can not make yield calls') unless Capataz.can_declare?(:yield)
      super
    end

    def on_def(node)
      report_error('can not define methods') unless Capataz.can_declare?(:def)
      super
      insert_before(node.location.expression, ";::Capataz.denied_override_of(self, :#{node.children[0]});") unless Capataz.allow_method_overrides
    end

    def on_self(_)
      report_error('can not access to self') unless Capataz.can_declare?(:self)
    end

    def on_yield(node)
      report_error('can not make yield calls') unless Capataz.can_declare?(:yield)
      super
    end

    def on_ivasgn(_)
      report_error('can not access instance variables') unless Capataz.can_declare?(:ivar)
      super
    end

    def on_ivar(_)
      report_error('can not access instance variables') unless Capataz.can_declare?(:ivar)
      super
    end

    def on_cvasgn(_)
      report_error('can not access class variables') unless Capataz.can_declare?(:cvar)
      super
    end

    def on_cvar(_)
      report_error('can not access class variables') unless Capataz.can_declare?(:cvar)
      super
    end

    def on_gvar(_)
      report_error('can not access global variables') unless Capataz.can_declare?(:gvar)
      super
    end

    def on_gvasgn(_)
      report_error('can not access global variables') unless Capataz.can_declare?(:gvar)
      super
    end

    private

    def report_error(message)
      if @options[:halt_on_error]
        fail message
      else
        @options[:errors] << message
      end
    end

    def capatize(node, options = {})
      if node && !@capatized_nodes.include?(node)
        @capatized_nodes << node
        options[:constant] = true if node.type == :const
        insert_before(node.location.expression, '::Capataz.handle(')
        if options.present?
          insert_after(node.location.expression, ", #{options.to_a.collect { |item| "#{item[0]}: #{item[1]}" }.join(',')})")
        else
          insert_after(node.location.expression, ')')
        end
      end
    end

    def const_from(node)
      if node
        const_from(node.children[0]) + '::' + node.children[1].to_s
      else
        ''
      end
    end
  end
end