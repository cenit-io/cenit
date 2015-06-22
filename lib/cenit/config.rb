module Cenit
  class << self

    def options
      @options ||=
        {
          service_url: 'http://localhost:3000', #TODO Automatize default service url
          service_schema_path: '/schema'
        }
    end

    def [](option)
      (value = options[option]).respond_to?(:call) ? value.call : value
    end

    def []=(option, value)
      options[option] = value
    end

    def config(&block)
      class_eval(&block) if block
    end

    def method_missing(symbol, *args)
      if !symbol.to_s.end_with?('=') && ((args.length == 0 && block_given?) || args.length == 1 && !block_given?)
        self[symbol] = block_given? ? yield : args[0]
      elsif args.length == 0 && !block_given?
        self[symbol]
      else
        super
      end
    end

  end
end