require 'json'
require 'openssl'
require 'bunny'

module Cenit
  class Rabbit

    class << self

      def send_to_rabbitmq(message)
        handler = message[:handler]
        msg_handler = handler.to_s.constantize rescue nil
        if handler == msg_handler
          message[:handler] = handler.to_s
        else
          fail "Invalid handler: #{handler}"
        end
        handler_method = message[:handler_method] || :process_message
        if (asynch_option = handler.try(:asynchronous_cenit_option, handler_method)) && Cenit.send(asynch_option)
          message[:token] = CenitToken.create(data: {account_id: Account.current.id.to_s}).token
          conn = Bunny.new(automatically_recover: false)
          conn.start
          ch = conn.create_channel
          q = ch.queue('cenit')
          ch.default_exchange.publish(message.to_json, routing_key: q.name)
          conn.close
        else
          process_message(message)
        end
      end

      def process_message(message)
        message = JSON.parse(message) unless message.is_a?(Hash)
        message = message.with_indifferent_access
        message_token = message.delete(:token)
        if token = CenitToken.where(token: message_token).first
          if account = Account.where(id: token.data[:account_id]).first
            Account.current = account if Account.current.nil?
          end
          token.destroy
        else
          account = nil
        end
        if Account.current.nil? || (message_token.present? && Account.current != account)
          Setup::Notification.create(exception_message: "Invalid message #{message}")
        else
          handler_str = message.delete(:handler)
          handler = handler_str.constantize rescue nil
          exception_message =
            if handler
              begin
                handler.send(message.delete(:handler_method) || :process_message, message)
                nil
              rescue Exception => ex
                ex.message
              end
            else
              "Invalid handler #{handler_str}"
            end
          Setup::Notification.create(exception_message: exception_message) if exception_message
        end
      end
    end
  end
end
