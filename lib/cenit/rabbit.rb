require 'json'
require 'openssl'
require 'bunny'

module Cenit
  class Rabbit

    def self.send_to_rabbitmq(message)
      conn = Bunny.new(:automatically_recover => false)
      conn.start

      ch = conn.create_channel
      q = ch.queue('send.to.endpoint')

      ch.default_exchange.publish(message, :routing_key => q.name)
      conn.close
    end

    def self.send_to_endpoint(message)
      message = JSON.parse(message)
      flow = Setup::Flow.find(message[:flow_id.to_s]['$oid'])
      object = message[:json_data.to_s]
      response = HTTParty.post(flow.connection.url + '/' + flow.webhook.path,
                               {
                                 body: object.to_json,
                                 headers: {
                                   'Content-Type'    => 'application/json',
                                   'X_HUB_STORE'     => flow.connection.number,
                                   'X_HUB_TOKEN'     => flow.connection.authentication_token,
                                   'X_HUB_TIMESTAMP' => Time.now.utc.to_i.to_s
                                 }
                               })
      notify_response_to_cenit(response, message)
    rescue Exception => exc
      notify_response_to_cenit(response, message, exc)
    end

    def self.notify_response_to_cenit(response, message, exception=nil)
      # Http codes:
      # 200...299 : OK
      # 300...399 : Redirect
      # 400...499 : Bad request
      # 500...599 : Internal Server Error

      notification = nil
      if message[:notification_id.to_s].nil?
        notification = Setup::Notification.new
        notification.flow_id = message[:flow_id.to_s]['$oid']
        notification.json_data = message[:json_data.to_s]
        notification.count = 0
      else
        notification = Setup::Notification.find(message[:notification_id.to_s]['$oid'])
      end

      if exception
        notification.http_status_message = exception.message
      else
        notification.http_status_code    = response.code
        notification.http_status_message = response.message
      end
      notification.count += 1
      notification.save!
    end

  end
end
