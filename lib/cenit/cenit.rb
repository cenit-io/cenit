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

    def default_file_store(*args)
      if args.length == 0
        options[:default_file_store] || file_stores.first
      else
        self[:default_file_store] = default_file_store = args[0]
        if options.key?(:file_stores)
          file_stores.delete(default_file_store)
          file_stores.unshift(default_file_store)
        end
        default_file_store
      end
    end

    def file_stores(*args)
      if args.length == 0
        options[:file_stores] || [options.key?(:default_file_store) ? default_file_store : Cenit::FileStore::LocalDb]
      else
        args = args.flatten
        if options.key?(:default_file_store)
          args.delete(default_file_store)
          args.unshift(default_file_store)
        end
        self[:file_stores] = args
      end
    end

    def file_stores_roles(*args)
      if args.length == 0
        options[:file_stores_roles]
      else
        self[:file_stores_roles] = args.flatten.collect(&:to_s)
      end
    end
  end
end