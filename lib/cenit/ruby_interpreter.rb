module Cenit
  class RubyInterpreter

    def method_missing(symbol, *args, &block)
      if algorithm = Setup::Algorithm.where(name: symbol).first
        instance_eval "define_singleton_method(:#{symbol},
        ->(#{(params = algorithm.parameters.collect { |p| p.name }).join(', ')}) {
          #{Capataz.rewrite(algorithm.code, locals: params)}
        })"
        send(symbol, *args, &block)
      else
        super
      end
    end

    def respond_to?(*args)
      Setup::Algorithm.where(name: args[0]).present?
    end

    def __run__(code, locals = {})
      locals = (locals || {}).with_indifferent_access
      code = Capataz.rewrite(code, locals: locals.keys)
      locals.each { |local, _| code = "#{local} = locals[:#{local}]\r\n" + code }
      instance_eval(code)
    end

    class << self
      def run(code, locals = {})
        new.__run__(code, locals)
      end
    end

  end
end