require 'cenit/core_ext'

module Cenit

  default_options service_url: '/service',
                  reserved_namespaces: %w(cenit default),
                  ecommerce_data_types: {},
                  rabbit_mq_queue: lambda { Mongoid.default_client.database.name }

  class << self

    def http_proxy
      if (address = http_proxy_address) && (port = http_proxy_port)
        "http://#{address}:#{port}"
      end
    end

    def http_proxy_options
      options = {}
      %w(http_proxy http_proxy_port http_proxy_user http_proxy_password).each do |option|
        if (option_value = send(option))
          options[option] = option_value
        end
      end
      options
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

    def namespace(name)
      Setup::Namespace.find_or_create_by(name: name)
    end
  end
end