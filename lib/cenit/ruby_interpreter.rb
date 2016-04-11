module Cenit
  class RubyInterpreter

    def initialize
      @prefixes = Hash.new { |h, linker| h[linker] = Hash.new { |h, method| h[method] = "__#{linker}_" } }
      @algorithms = {}.with_indifferent_access
      @options = {}
    end

    def method_missing(symbol, *args, &block)
      if @options[:linking_algorithms] && (algorithm = @algorithms[symbol])
        if algorithm.is_a?(Proc)
          define_singleton_method(symbol, algorithm)
        else
          instance_eval "define_singleton_method(:#{symbol},
        ->(#{(params = algorithm.parameters.collect { |p| p.name }).join(', ')}) {
          #{Capataz.rewrite(algorithm.code, locals: params, self_linker: algorithm, self_send_prefixer: @prefixer)}
        })"
        end
        send(symbol, *args, &block)
      else
        super
      end
    end

    def respond_to?(*args)
      @algorithms.has_key?(args[0])
    end

    def __run__(*args)
      fail "Code expected as first argument but #{code.class} found" unless (code = args.shift).is_a?(String)
      if (locals = args.shift || {}).is_a?(Hash)
        locals = locals.symbolize_keys
      else
        fail "Locals hash expected as second argument but #{locals.class} found"
      end
      if (@options = args.shift || {}).is_a?(Hash)
        @options = @options.symbolize_keys
        @options[:linking_algorithms] = true unless @options.has_key?(:linking_algorithms)
      else
        fail "Options hash expected as third argument but #{@options.class} found"
      end
      code = Capataz.rewrite(code, locals: locals.keys,
                             self_linker: @options[:self_linker],
                             self_send_prefixer: @prefixer = Prefixer.new(self))
      locals.each { |local, _| code = "#{local} = ::Capataz.handle(locals[:#{local}])\r\n" + code }
      instance_eval(code)
    end

    class << self
      def run(*args)
        new.__run__(*args)
      end
    end

    class Prefixer

      def initialize(interpreter)
        @interpreter = interpreter
      end

      def prefix(method, linker)
        prefix = @interpreter.instance_variable_get(:@prefixes)[linker.linker_id][method]
        @interpreter.instance_variable_get(:@algorithms)[(prefix + method.to_s).to_sym] = linker.link(method)
        prefix
      end
    end

  end
end