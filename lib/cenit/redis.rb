require 'redis'

module Cenit
  module Redis
    class << self

      def new
        client? && ::Redis.new
      end

      def client?
        !client.nil?
      end

      def client
        unless instance_variable_defined?(:@redis_client)
          client = ::Redis.new
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