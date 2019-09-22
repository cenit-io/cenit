module Capataz
  class << self
    def allow_invoke_of(methods)
      @config[:allowed_methods] ||= []
      symbol_array_store(:allowed_methods, methods)
    end

    def allowed_method_with_allow_invoke?(options, instance, method)
      @config[:allowed_methods] ||= []
      @config[:allowed_methods].include?(method) || allowed_method_without_allow_invoke?(options, instance, method)
    end

    alias_method_chain :allowed_method?, :allow_invoke

    alias_method :native_rewrite, :rewrite

    if ENV['CAPATAZ_CODE_CACHE'].to_b
      def rewrite(code, options = {})
        Cache.rewrite(code, options)
      end
    end
  end

  module Cache
    extend self

    CODE_PREFIX = 'capatized_code_'
    ZCODES_KEY = 'capatized_codes'

    def cache_key_for(code_key)
      "#{CODE_PREFIX}#{code_key}"
    end

    def rewrite(code, options)
      if Cenit::Redis.client? && (code_key = options[:code_key])
        cache_key = cache_key_for(code_key)
        unless (code_cache = Cenit::Redis.get(cache_key))
          clean_strategy.call
          code_cache = Capataz.native_rewrite(code, options)
          Cenit::Redis.set(cache_key, code_cache)
          Cenit::Redis.zincrby(ZCODES_KEY, 1, code_key)
        end
        code_cache
      else
        Capataz.native_rewrite(code, options)
      end
    end

    def size
      Cenit::Redis.zcount(ZCODES_KEY, '1', '+inf')
    rescue
      0
    end

    def clean(*args)
      if Cenit::Redis.client?
        keys =
          if args.length > 0
            Cenit::Redis.zrem(ZCODES_KEY, *args)
            args.map(&method(:cache_key_for))
          else
            Cenit::Redis.del(ZCODES_KEY)
            Cenit::Redis.keys("#{CODE_PREFIX}*")
          end
        Cenit::Redis.del *keys if keys.count > 0
        true
      else
        false
      end
    end

    attr_accessor :clean_strategy

    NEVER_CLEAN = proc {}

    BASIC_CLEAN = proc do
      ::Capataz::Cache.clean if ::Capataz::Cache.size >= 2 * ::Cenit::Rabbit.maximum_active_tasks
    end
  end
end

Capataz::Cache.clean_strategy = Capataz::Cache::BASIC_CLEAN