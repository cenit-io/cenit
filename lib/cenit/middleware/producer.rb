require 'json'
require 'openssl'
require 'bunny'

module Cenit
  module Middleware
    class Producer

      def self.process(object, path, with_id)
        object_hash = parse_object(object, with_id)
        webhook = Setup::Webhook.where(path: path).first
        if webhook
          endpoints = webhook.connections.select{|c| c.id != object.connection_id}
          endpoints.each do |conn|
            message = {
              :object => object_hash,
              :url => "#{conn.url}/#{webhook.path}",
              :store => conn.store,
              :token => conn.token
            }.to_json
            send_to_rabbitmq(message)
          end
        end
      end

      def self.send_to_rabbitmq(message)
        conn = Bunny.new(:automatically_recover => false)
        conn.start

        ch = conn.create_channel
        q = ch.queue('send.to.website')

        ch.default_exchange.publish(message, :routing_key => q.name)
        conn.close
      end

      def self.parse_object(object, with_id)
        object_hash = JSON.parse(object.to_json)
        object_id = object_hash.delete '_id'
        object_hash['id'] = object_id if with_id
        object_hash.delete 'connection_id'
        key = object.class.to_s.downcase.split('::').last
        {key => object_hash}
      end

    end
  end
end
