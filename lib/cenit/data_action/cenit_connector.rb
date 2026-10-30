require_relative 'receiver'
require_relative 'delivery_errors'

module Cenit
  module DataAction
    # Bounded local qualification adapter using Cenit's real Connection/Webhook.
    # Deliberately limited to the loopback simulator's idempotency/lookup protocol.
    class CenitConnector
      PROTOCOL = 'local-effect-v1'.freeze
      def initialize(connection:, deliver_webhook:, lookup_webhook:, allow_local: false)
        unless allow_local && connection.is_a?(Setup::Connection) && deliver_webhook.is_a?(Setup::PlainWebhook) && lookup_webhook.is_a?(Setup::PlainWebhook)
          raise ArgumentError, 'An explicit local Cenit connector is required.'
        end
        @connection, @post, @get = connection, deliver_webhook, lookup_webhook
        digest
      end
      def digest
        [@connection, @post, @get].each do |configuration|
          raise ArgumentError, 'Persisted connector configuration is required.' unless configuration.persisted?
          configuration.reload
          unless configuration.headers.empty? && configuration.parameters.empty? && configuration.template_parameters.empty? && !configuration.using_authorization
            raise ArgumentError, 'The local simulator connector requires plain, fixed configuration.'
          end
        end
        uri = URI.parse(@connection.url)
        unless uri.scheme == 'http' && Client::LOCAL_HOSTS.include?(uri.hostname) && !uri.userinfo && !uri.query && !uri.fragment && ['', '/'].include?(uri.path) &&
            @post.path == '/effects/{{ effect_key }}' && @get.path == @post.path && @post.method.to_s == 'post' && @get.method.to_s == 'get'
          raise ArgumentError, 'Only the fixed local effect protocol is supported.'
        end
        Receiver.digest([PROTOCOL, @connection.id.to_s, @connection.url, @post.id.to_s, @post.path, @post.method.to_s, @get.id.to_s, @get.path, @get.method.to_s])
      end
      def lookup(key)
        response = submit(@get, key)
        return nil if response.code.to_i == 404
        decode(response)
      end
      def deliver(key, body)
        decode(submit(@post, key, body))
      end
      private
      def submit(webhook, key, body = nil)
        raise ArgumentError, 'A stable effect key is required.' unless key.is_a?(String) && key.match?(/\A[0-9a-f]{64}\z/)
        budget_key = Setup::WebhookCommon::REQUEST_TIME_KEY
        previous_budget = Thread.current[budget_key]
        Thread.current[budget_key] = [previous_budget || 15, 15].min
        options = { contentType: 'application/json', template_parameters: { 'effect_key' => key },
          headers: { 'Idempotency-Key' => key }, verbose_response: true,
          request_attachment: ->(_attachment) { nil } }
        options[:body] = body if body
        result = webhook.with(@connection).submit!(options)
        response = result[:http_response]
        raise DeliveryFailure.new('DOWNSTREAM_UNAVAILABLE', retryable: true) unless response
        response
      rescue DeliveryFailure, ArgumentError
        raise
      rescue StandardError
        raise DeliveryFailure.new('DOWNSTREAM_UNAVAILABLE', retryable: true), cause: nil
      ensure
        Thread.current[budget_key] = previous_budget if budget_key
      end
      def decode(response)
        code = response.code.to_i
        unless code.between?(200, 299)
          raise DeliveryFailure.new('DOWNSTREAM_REJECTED', retryable: code >= 500 || [408, 429].include?(code))
        end
        body = response.body.to_s
        raise DeliveryFailure.new('INVALID_RECEIPT', retryable: false) if body.bytesize > 4_000
        begin
          receipt = JSON.parse(body)
        rescue JSON::ParserError
          raise DeliveryFailure.new('INVALID_RECEIPT', retryable: false), cause: nil
        end
        raise DeliveryFailure.new('INVALID_RECEIPT', retryable: false) unless receipt.is_a?(Hash)
        receipt
      end
    end
  end
end
