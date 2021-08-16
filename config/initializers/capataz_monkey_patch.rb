require 'cenit/redis'

module Capataz
  class << self

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
        if (code_cache = Cenit::Redis.get(cache_key))
          code_cache = JSON.parse(code_cache)
          if (links = options[:links]) && links.length > 0
            algorithms = Setup::Algorithm.where(:id.in => code_cache['links'].values).map { |alg| [alg.id.to_s, alg] }.to_h
            code_cache['links'].each do |key, alg_id|
              links[key] = algorithms[alg_id]
            end
          end
          code_cache['code']
        else
          clean_strategy.call
          unless (links = options[:links])
            links = options[:links] = {}
          end
          code_cache = {
            code: code = Capataz.native_rewrite(code, options),
            links: links.map { |key, alg| [key, alg.id.to_s] }.to_h
          }
          Cenit::Redis.set(cache_key, code_cache.to_json)
          Cenit::Redis.zincrby(ZCODES_KEY, 1, code_key)
          code
        end
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