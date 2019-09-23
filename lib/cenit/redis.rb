require 'redis'

module Cenit
  module Redis
    class << self

      def client?
        !client.nil?
      end

      def client
        unless instance_variable_defined?(:@redis_client)
          client =
            if ( ENV['REDIS_URL'] )
              redis_url = ENV['REDIS_URL']
              # specify a connection option as a redis:// URL
              # e.g "redis://:p4ssw0rd@10.0.1.1:6380/15"
              ::Redis.new(url: redis_url)
            else
              # Defauls values similar to the redis gem
              # https://github.com/redis/redis-rb/blob/master/lib/redis/client.rb#L10-L26
              redis_host = ENV['REDIS_HOST'] || '127.0.0.1'
              redis_port = (ENV['REDIS_PORT'] || 6379).to_i
              redis_db = (ENV['REDIS_DB'] || 0).to_i
              redis_password = ENV['REDIS_PASSWORD'] || nil
              
              ::Redis.new(host: redis_host, port: redis_port, db: redis_db, password: redis_password)
            end
          client =
            begin
              client.ping
              puts 'Redis connection detected!'
              client
            rescue Exception => ex
              puts "Redis connection rejected: #{ex.message}"
              nil
            end
          instance_variable_set(:@redis_client, client)
        end
        instance_variable_get(:@redis_client)
      end

      def pipelined
        yield client if client && block_given?
      end

      def method_missing(symbol, *args, &block)
        if client&.respond_to?(symbol)
          client.send(symbol, *args, &block)
        else
          super
        end
      end
    end
  end
end