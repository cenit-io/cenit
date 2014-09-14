require 'json'
require 'openssl'
require 'bunny'

module Cenit
  class Rabbit

    def self.send_to_rabbitmq(message)
      conn = Bunny.new(:automatically_recover => false)
      conn.start

      ch = conn.create_channel
      q = ch.queue('send.to.website')

      ch.default_exchange.publish(message, :routing_key => q.name)
      conn.close
    end

    def self.receive_from_rabbitmq(message)
      message = JSON.parse(message)
      response = HTTParty.post(message['url'],
                               {
                                 body: message['body'].to_json,
                                 headers: {
                                   'Content-Type'    => 'application/json',
                                   'X_HUB_STORE'     => message['store'],
                                   'X_HUB_TOKEN'     => message['token'],
                                   'X_HUB_TIMESTAMP' => Time.now.utc.to_i.to_s
                                 }
                               })
      if message['purpose'] == 'receive'
        handler = Handler.new(response, message['object'])
        handler.process
      end
    end

  end
end
