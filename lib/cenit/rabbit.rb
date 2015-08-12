require 'json'
require 'openssl'
require 'bunny'

module Cenit
  class Rabbit

    class << self

      def send_to_rabbitmq(message)
        conn = Bunny.new(:automatically_recover => false)
        conn.start

        ch = conn.create_channel
        q = ch.queue('send.to.endpoint')

        ch.default_exchange.publish(message, :routing_key => q.name)
        conn.close
      end

      def process_message(message)
        hash_message = JSON.parse(message).with_indifferent_access
        if flow = Setup::Flow.where(id: flow_id = hash_message[:flow_id]).first
          flow.translate(hash_message) do |translation_result|
            notify_to_cenit(translation_result.merge(message: message,
                                                     flow: flow,
                                                     notification_id: hash_message[:notification_id]))
          end
        else
          notify_to_cenit(exception_message: "Flow with id #{flow_id} not found")
        end
      end

      def notify_to_cenit(translation)
        # Http codes:
        # 200...299 : OK
        # 300...399 : Redirect
        # 400...499 : Bad request
        # 500...599 : Internal Server Error


        notification =
            (translation[:notification_id] && Setup::Notification.where(id: translation[:notification_id]).first) ||
                Setup::Notification.new(flow: translation[:flow],
                                        message: translation[:message],
                                        exception_message: translation[:exception_message])
        notification.response = translation[:response].to_s
        notification.retries += 1 unless notification.new_record?
        notification.save
      end

    end
  end
end
