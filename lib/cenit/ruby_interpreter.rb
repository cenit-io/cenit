module Cenit
  class RubyInterpreter

    def initialize
      @prefixes = Hash.new { |h, linker| h[linker] = Hash.new { |h, method| h[method] = "__#{linker}_" } }
      @algorithms = {}.with_indifferent_access
    end

    def method_missing(symbol, *args, &block)
      if algorithm = @algorithms[symbol]
        instance_eval "define_singleton_method(:#{symbol},
        ->(#{(params = algorithm.parameters.collect { |p| p.name }).join(', ')}) {
          #{Capataz.rewrite(algorithm.code, locals: params, self_linker: algorithm, self_send_prefixer: @prefixer)}
        })"
        send(symbol, *args, &block)
      else
        super
      end
    end

    def respond_to?(*args)
      @algorithms.has_key?(args[0])
    end

    def __run__(*args)
      locals = (args.last.is_a?(Hash) ? args.pop : {}).symbolize_keys
      code = args.shift.to_s
      code = Capataz.rewrite(code, locals: locals.keys, self_linker: args.first, self_send_prefixer: @prefixer = Prefixer.new(self))
      locals.each { |local, _| code = "#{local} = locals[:#{local}]\r\n" + code }
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