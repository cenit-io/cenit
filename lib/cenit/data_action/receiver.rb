require 'digest'
require_relative 'client'

module Cenit
  module DataAction
    # Receives a bounded, pinned order-created contract; no business record is saved here.
    class Receiver
      def initialize(client:, inbox:, workspace_id:, environment_id:, object_type_version_id:,
          subscription_id:, query_version_id:, mapping_version:, mapping_digest:, connector_digest:)
        [workspace_id, environment_id, object_type_version_id, subscription_id, query_version_id].each do |id|
          raise ArgumentError, 'A pinned UUID configuration is required.' unless id.is_a?(String) && id.match?(Client::UUID)
        end
        unless mapping_version.is_a?(String) && !mapping_version.empty? && mapping_version.bytesize <= 100 &&
            [mapping_digest, connector_digest].all? { |value| value.is_a?(String) && value.match?(/\A[0-9a-f]{64}\z/) }
          raise ArgumentError, 'A versioned mapping digest is required.'
        end
        @client, @inbox = client, inbox
        @workspace, @environment, @type = workspace_id, environment_id, object_type_version_id
        @subscription, @query, @mapping, @mapping_digest, @connector_digest = subscription_id, query_version_id, mapping_version, mapping_digest, connector_digest
      end

      def receive(claim)
        event = claim.is_a?(Hash) && claim['event']
        data = event.is_a?(Hash) && event['data']
        subject = event.is_a?(Hash) && event['subject']
        unless event.is_a?(Hash) && data.is_a?(Hash) && subject.is_a?(Hash) &&
            event['eventType'] == 'ObjectRecordCreated' && event['eventVersion'] == '1.0' &&
            event['workspaceId'] == @workspace && event['environmentId'] == @environment &&
            data['objectTypeVersionId'] == @type && claim['eventId'] == event['eventId'] &&
            subject['type'] == 'ObjectRecord' && subject['id'] == data['recordId'] && subject['version'] == data['revision'] &&
            data['revision'].is_a?(Integer) && data['revision'].positive? &&
            [event['eventId'], data['recordId'], claim['fence'], event['correlationId'], event['causationId']].all? { |id| id.is_a?(String) && id.match?(Client::UUID) }
          raise ProtocolError, 'The event does not match the pinned integration contract.'
        end
        result = @client.query(@query, record_id: data['recordId'], revision: data['revision'])
        records = result.is_a?(Hash) && result['records']
        snapshot = records.is_a?(Array) && records.length == 1 && records.first
        unless snapshot.is_a?(Hash) && snapshot['id'] == data['recordId'] && snapshot['revision'] == data['revision'] &&
            snapshot['workspaceId'] == @workspace && snapshot['typeId'] == @type && snapshot['data'].is_a?(Hash)
          raise ProtocolError, 'The exact committed event revision is unavailable.'
        end
        entry = {
          'event_id' => event['eventId'], 'workspace_id' => @workspace, 'environment_id' => @environment,
          'subscription_id' => @subscription, 'query_version_id' => @query, 'object_type_version_id' => @type,
          'record_id' => data['recordId'], 'revision' => data['revision'], 'correlation_id' => event['correlationId'],
          'causation_id' => event['causationId'], 'mapping_version' => @mapping, 'mapping_digest' => @mapping_digest,
          'data_digest' => self.class.digest(snapshot['data']), 'connector_digest' => @connector_digest,
          'effect_key' => self.class.digest([@workspace, @environment, @subscription, event['eventId'], @mapping, @mapping_digest]),
          'state' => 'pending', 'attempts' => 0
        }
        # The inbox must atomically store both receipt and pending work before returning.
        @inbox.accept(entry)
        @client.ack(@subscription, event_id: claim['eventId'], fence: claim['fence'])
        entry
      end

      def self.digest(value)
        Digest::SHA256.hexdigest(JSON.generate(canonical(value)))
      end
      def self.canonical(value)
        case value
        when Hash then value.keys.sort.each_with_object({}) { |key, result| result[key] = canonical(value.fetch(key)) }
        when Array then value.map { |item| canonical(item) }
        else value
        end
      end
    end
  end
end
