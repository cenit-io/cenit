require 'parser/current'

module Capataz


  class << self

    def deny_declarations_of(*symbols)
      symbol_array_store(:denied_declarations, symbols)
    end

    def deny_invoke_of(*methods)
      symbol_array_store(:denied_methods, methods)
    end

    def allowed_constants(*constants)
      set = @config[:allowed_constants]
      constants = [constants] unless constants.is_a?(Enumerable)
      constants << Capataz unless constants.include?(Capataz)
      constants.each { |constant| set << constant }
    end

    def allow_on(objs, *methods)
      store_options(:instances, :allow, objs, methods)
    end

    def deny_on(objs, *methods)
      store_options(:instances, :deny, objs, methods)
    end

    def allow_for(types, *options)
      store_options(:modules, :allow, types, options) { |type| type.is_a?(Module) }
    end

    def deny_for(types, *options)
      store_options(:modules, :deny, types, options) { |type| type.is_a?(Module) }
    end

    def config(&block)
      @config ||=
        {
          denied_declarations: Set.new,
          allowed_constants: Set.new,
          denied_methods: Set.new,
          instances: {},
          modules: {}
        }
      class_eval(&block) if block
      @config
    end

    def instance_response_to?(instance, *args)
      fail ArgumentError if args.length == 0
      method = args[0].is_a?(Symbol) ? args[0] : args[0].to_s.to_sym
      return false if @config[:denied_methods].include?(method)
      if options = @config[:instances][instance]
        return false unless allowed_method?(options, instance, method)
      else
        @config[:modules].each do |type, options|
          if instance.is_a?(type)
            return false unless allowed_method?(options, instance, method)
          end
        end
      end
      instance.respond_to?(*args)
    end

    def allows_invocation_of(method)
      method = method.to_s.to_sym unless method.is_a?(Symbol)
      return false if @config[:denied_methods].include?(method)
      true
    end

    def allowed_constant?(const)
      (set = @config[:allowed_constants]) && set.include?(const)
    end

    def can_declare?(symbol)
      (set = @config[:denied_declarations]).empty? || !set.include?(symbol)
    end

    def validate(code)
      errors = []
      begin
        buffer = Parser::Source::Buffer.new('code')
        buffer.source = code
        Capataz::Rewriter.new(errors: errors).rewrite(buffer, Parser::CurrentRuby.new.parse(buffer))
      rescue => ex
        errors << ex.message
      end
      errors
    end

    def rewrite(code, options = {})
      options ||= {}
      options[:halt_on_error] = true if options[:halt_on_error].nil?
      if locals = options[:locals]
        locals = [locals] unless locals.is_a?(Enumerable)
        locals.each { |local| code = "#{local} ||= nil\r\n" + code }
      end
      buffer = Parser::Source::Buffer.new('code')
      buffer.source = code
      Capataz::Rewriter.new(options).rewrite(buffer, Parser::CurrentRuby.new.parse(buffer))
    end

    def handle(obj, options = {})
      if obj.capataz_proxy? || [NilClass, Fixnum, Symbol, String, TrueClass, FalseClass].any? { |type| obj.is_a?(type) }
        obj
      elsif obj.is_a?(Hash)
        Capataz::HashProxy.new(obj)
      else
        Capataz::Proxy.new(obj, options)
      end
    end

    private

    def allow_method_overrides
      true #TODO Setup on config
    end

    def allowed_method?(options, instance, method)
      if (allow = options[:allow])
        if allow.is_a?(Proc)
          return false if !allow.call(instance, method)
        else
          return false unless allow.include?(method)
        end
      end
      if (deny = options[:deny])
        if deny.is_a?(Proc)
          return false if deny.call(instance, method)
        else
          return false if deny.include?(method)
        end
      end
      true
    end

    def symbol_array_store(key, symbols)
      set = @config[key]
      symbols = [symbols] unless symbols.is_a?(Enumerable)
      symbols.each { |symbol| set << (symbol.is_a?(Symbol) ? symbol : symbol.to_s.to_sym) }
    end

    def instances_store(key, objs, methods)
      methods = [methods] unless methods.is_a?(Enumerable)
      methods = methods.to_a.collect { |method| method.is_a?(Symbol) ? method : method.to_s.to_sym }
      objs = [objs] unless objs.is_a?(Enumerable)
      instances = @config[:instances]
      objs.each do |obj|
        (instances[obj] ||= {}).merge!(key => methods)
      end
    end

    def store_options(entry_key, access_key, objs, options)
      if options.is_a?(Enumerable)
        options = options.flatten if options.is_a?(Array)
      else
        options = [options]
      end
      options =
        if options.length == 1 && options[0].is_a?(Proc)
          options[0]
        else
          options.collect { |option| option.is_a?(Symbol) ? option : option.to_s.to_sym }
        end
      objs = [objs] unless objs.is_a?(Enumerable)
      entry = @config[entry_key]
      objs.each do |obj|
        if block_given?
          fail "Illegal object #{obj}" unless yield(obj)
        end
        (entry[obj] ||= {}).merge!(access_key => options)
      end
    end

  end

  Capataz.config
end