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

    def _js_context__
      unless @__js_context
        @__js_context = MiniRacer::Context.new
        @__js_context.attach('__interpreter_args', proc { @__js_arguments__.last })
        @__js_context.attach('__interpreter_run', proc { |*args| method_missing(args.shift, *args) })
      end
      @__js_context
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
        @__wrapper__.bundle(symbol, algorithm)
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
        @bundling_stack = []
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
        method =
          begin
            interpreter.method(symbol)
          rescue
            nil
          end
        unless method
          if algorithm.is_a?(Proc)
            interpreter.define_singleton_method(symbol, algorithm)
            method = interpreter.method(symbol)
          else
            bundle_method = "bundled_#{algorithm.language}_code"
            if respond_to?(bundle_method)
              @bundling_stack << symbol
              interpreter.instance_eval "define_singleton_method :#{symbol} do |*args|
                #{send(bundle_method, algorithm)}
              end"
              @bundling_stack.pop
              algorithms[symbol] = algorithm
              method = interpreter.method(symbol)
            else
              fail "Language #{algorithm.language_name} not supported by bundler interpreter"
            end
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
        links = {}
        required_size = algorithm.required_parameters_size
        code = "fail \"expected #{required_size} args when invoking #{algorithm.name} but got \#{args.length}\" if args.length < #{required_size};" +
          params_initializer + Capataz.rewrite(algorithm.code,
                                               code_key: algorithm.code_key,
                                               locals: locals,
                                               self_linker: options[:self_linker] || algorithm.self_linker || algorithm,
                                               self_send_prefixer: self,
                                               links: links,
                                               iteration_counter_prefix: "alg#{algorithm.id}_it",
                                               invoke_counter_prefix: "alg#{algorithm.id}_invk")
        links.each do |key, alg|
          next if @bundling_stack.include?(key)
          bundle(key, alg)
        end
        code
      rescue Exception => ex
        raise "Error bundling algorithm #{algorithm.custom_title}: #{ex.message}"
      end

      def bundled_javascript_code(algorithm)
        arguments_param = false
        i = -1
        js_vars = ''
        params_initializer =
          "arguments = {}\n" +
            algorithm.parameters.collect do |p|
              js_vars += "var #{p.name} = __interpreter_args()['#{p.name}'];\n"
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
            node.value = "__INTERPRETER_RUN__(#{call_name_prefix + call_name})"
          end
          js_fn = "____f#{rand}".tr('.', '_')
          js_code = <<-CODE
            function #{js_fn}(){
              #{js_vars}

              #{ast.to_ecma}
            }
          CODE
          js_code.gsub!(/__INTERPRETER_RUN__\((.*)\)\(/) do
            "__interpreter_run('#{::Regexp.last_match[1]}',"
          end
          interpreter._js_context__.eval(js_code, thread_safe: true)
          required_size = algorithm.required_parameters_size
          "fail \"expected #{required_size} args when invoking #{algorithm.name} but got \#{args.length}\" if args.length < #{required_size}\n" +
          params_initializer + "\nresult = _js_context__.eval '#{js_fn}()', thread_safe: true
          @__js_arguments__.pop
          result"
        else
          fail "Error bundling algorithm #{algorithm.custom_title}:JavaScript syntax error"
        end
      end
    end
  end
end
