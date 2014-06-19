require 'json'
require 'openssl'
require 'httparty'


module Cenit
  module Middleware
    class Consumer

      # TODO: create a noitfication from response
      def self.process(message)
        message = JSON.parse(message)
        response = HTTParty.post(message['url'],
                   {
                      body: message['object'].to_json,
                      headers: {
                         'Content-Type'         => 'application/json',
                         'X_HUB_STORE'     => message['store'],
                         'X_HUB_TOKEN'     => message['token'],
                         'X_HUB_TIMESTAMP' => Time.now.utc.to_i.to_s
                      }
                   })
      end

    end
  end
end
