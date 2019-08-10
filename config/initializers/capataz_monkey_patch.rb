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

    def rewrite(code, options = {})
      Cache.rewrite(code, options)
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
        code_key = cache_key_for(code_key)
        unless (code_cache = Cenit::Redis.get(code_key))
          code_cache = Capataz.native_rewrite(code, options)
          Cenit::Redis.set(code_key, code_cache)
        end
        code_cache
      else
        Capataz.native_rewrite(code, options)
      end
    end

    def clean(*args)
      if Cenit::Redis.client?
        keys =
          if args.length > 0
            args.map(&method(:cache_key_for))
          else
            Cenit::Redis.keys("#{CODE_PREFIX}*")
          end
        Cenit::Redis.del *keys if keys.count > 0
      end
    end
  end
end