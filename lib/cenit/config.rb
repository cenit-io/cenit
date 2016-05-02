require 'cenit/core_ext'

module Cenit
  class << self

    def http_proxy_options
      options = {}
      %w(http_proxy http_proxy_port http_proxy_user http_proxy_password).each do |option|
        if option_value = send(option)
          options[option] = option_value
        end
      end
      options
    end

    def dynamic_model_loading?
      !excluded_actions.include?(:load_model)
    end

    def excluded_actions(*args)
      if args.length == 0
        options[:excluded_actions]
      else
        self[:excluded_actions] = args.flatten.collect(&:to_s).join(' ').split(' ').collect(&:to_sym)
      end
    end

    def reserved_namespaces(*args)
      if args.length == 0
        options[:reserved_namespaces]
      else
        self[:reserved_namespaces] = (options[:reserved_namespaces] + args[0].flatten.collect(&:to_s).collect(&:downcase)).uniq
      end
    end

    def options
      @options ||=
        {
          service_url: 'http://localhost:3000', #TODO Automatize default service url
          service_schema_path: '/schema',
          reserved_namespaces: %w(cenit default)
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

    def respond_to?(*args)
      super || options.has_key?(args[0])
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