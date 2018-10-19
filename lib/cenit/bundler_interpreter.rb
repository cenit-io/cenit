module Cenit
  # Run Algorithms bundling all required code in a single ruby execution context.
  class BundlerInterpreter
    attr_reader :__wrapper__

    def initialize(options = {})
      @__prefixes__ = Hash.new do |linkers, linker_id|
        linkers[linker_id] = Hash.new do |methods, method|
          methods[method] = "__#{linker_id}_"
        end
      end
      @__algorithms__ = {}
      @__options__ = { linking_algorithms: true }.merge(options)
      @__js_arguments__ = []
      @__wrapper__ = Wrapper.new(self)
    end

    def __v8_context__
      @__v8_context ||= V8::Context.new(with: self)
    end

    def [](name)
      if (args = @__js_arguments__.last) && args.key?(name)
        args[name]
      else
        yield if block_given?
      end
    end

    def method_missing(symbol, *args, &block)
      symbol = symbol.to_s
      if (algorithm = @__algorithms__[symbol])
        if algorithm.is_a?(Proc)
          define_singleton_method(symbol, algorithm)
        else
          @__wrapper__.bundle(symbol, algorithm)
        end
        send(symbol, *args, &block)
      else
        super
      end
    end

    def respond_to?(*args)
      @__algorithms__.key?(args[0].to_s)
    end

    def __run__(algorithm, *args)
      run_name = "__run__#{algorithm.name}"
      @__algorithms__[run_name] = algorithm
      send run_name, *args
    end

    class << self
      def run_code(*args)
        fail "Code expected as first argument but #{code.class} found" unless (code = args.shift).is_a?(String)
        if (locals = args.shift || {}).is_a?(Hash)
          locals = locals.symbolize_keys
        else
          fail "Locals hash expected as second argument but #{locals.class} found"
        end
        if (options = args.shift || {}).is_a?(Hash)
          options = options.symbolize_keys
          options[:linking_algorithms] = true unless options.key?(:linking_algorithms)
        else
          fail "Options hash expected as third argument but #{options.class} found"
        end
        algorithm = Setup::Algorithm.new(name: "alg#{code.object_id}", code: code, language: :ruby)
        input = []
        locals.each do |local, value|
          input << value
          algorithm.parameters.new(name: local)
        end
        do_run(algorithm, input, options)
      end

      def do_run(algorithm, input, options = {})
        input = [input] unless input.is_a?(Array)
        new(options).__run__(algorithm, *input)
      end

      def run(algorithm, *args)
        do_run(algorithm, args)
      end
    end

    private

    # Wraps a bundle interpreter to access its attributes through friendly names.
    class Wrapper
      attr_reader :interpreter

      def initialize(interpreter)
        @interpreter = interpreter
      end

      def algorithms
        interpreter.instance_variable_get(:@__algorithms__)
      end

      def options
        interpreter.instance_variable_get(:@__options__)
      end

      def prefix(method, linker)
        if options[:linking_algorithms]
          prefix = interpreter.instance_variable_get(:@__prefixes__)[linker.linker_id][method]
          algorithms[prefix + method.to_s] = linker.link(method)
          prefix
        else
          ''
        end
      end

      def bundle(symbol, algorithm)
        method = interpreter.method(symbol) rescue nil
        unless method
          bundle_method = "bundled_#{algorithm.language}_code"
          if respond_to?(bundle_method)
            interpreter.instance_eval "define_singleton_method :#{symbol} do |*args|
              #{send(bundle_method, algorithm)}
            end"
            method = interpreter.method(symbol)
          else
            fail "Language #{algorithm.language_name} not supported by bundler interpreter"
          end
        end
        method
      end

      def bundled_ruby_code(algorithm)
        locals = %w(args)
        args_param = false
        i = -1
        params_initializer =
          algorithm.parameters.collect do |p|
            locals << p.name
            args_param ||= p.name == 'args'
            i += 1
            "#{p.name} = (args.length > #{i} ? args[#{i}] : #{p.default_ruby})"
          end.join(';') + ';'
        if args_param
          args = "__args#{rand}".tr('.', '_')
          params_initializer = "#{args}=args;" + params_initializer.gsub('=args[', "=#{args}[")
        end
        params_initializer + Capataz.rewrite(algorithm.code,
                                             locals: locals,
                                             self_linker: options[:self_linker] || algorithm.self_linker || algorithm,
                                             self_send_prefixer: self,
                                             iteration_counter_prefix: "alg#{algorithm.id}_it",
                                             invoke_counter_prefix: "alg#{algorithm.id}_invk")
      rescue Exception => ex
        raise "Error bundling algorithm #{algorithm.custom_title}: #{ex.message}"
      end

      def bundled_javascript_code(algorithm)
        arguments_param = false
        i = -1
        params_initializer = "arguments = {}\n" +
          algorithm.parameters.collect do |p|
            arguments_param ||= p.name == 'arguments'
            i += 1
            "arguments['#{p.name}'] = (args.length > #{i} ? args[#{i}] : #{p.default_javascript})"
          end.join("\n") + "\n"
        params_initializer += "arguments['arguments']=args\n" unless arguments_param
        params_initializer += '@__js_arguments__ << arguments'
        ast = RKelly.parse(algorithm.code) rescue nil
        if ast
          ast.each do |node|
            next unless node.is_a?(RKelly::Nodes::FunctionCallNode) && (node = node.value).is_a?(RKelly::Nodes::ResolveNode)
            call_name = node.value
            call_name_prefix = prefix(call_name, algorithm)
            node.value = call_name_prefix + call_name
          end
          params_initializer + "\nresult = __v8_context__.eval <<-CODE
            var #{f_var = "____f#{rand}".tr('.', '_')} = function(){
              #{ast.to_ecma}
            }
            #{f_var}();
          CODE
          @__js_arguments__.pop
          result"
        else
          fail "Error bundling algorithm #{algorithm.custom_title}:JavaScript syntax error"
        end
      end
    end
  end
end

require 'v8/access/names'
require 'v8/conversion/class'

module V8
  class Access
    module Names
      alias_method :rkelly_get, :get

      def get(obj, name, &dontintercept)
        if obj.is_a?(Cenit::BundlerInterpreter)
          wrapper = obj.__wrapper__
          if (algorithm = wrapper.algorithms[name.to_s])
            wrapper.bundle(name, algorithm).unbind
          elsif !special?(name)
            obj.send(:[], name, &dontintercept)
          else
            yield
          end
        else
          rkelly_get(obj, name, &dontintercept)
        end
      end
    end
  end
end
