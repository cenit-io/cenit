require 'mongo'
require_relative 'receiver'

module Cenit
  module DataAction
    # Private Cenit execution storage. Receipt and pending work share one atomic
    # document; no multi-document transaction or remote business record is needed.
    class MongoInbox
      REFERENCE_FIELDS = %w[event_id workspace_id environment_id subscription_id query_version_id
        object_type_version_id record_id revision correlation_id causation_id mapping_version mapping_digest
        data_digest effect_key].freeze
      def initialize(collection:, account_id:, profile_id:)
        unless [account_id, profile_id].all? { |id| id.is_a?(String) && !id.empty? && id.bytesize <= 200 }
          raise ArgumentError, 'Trusted account and integration profile scope are required.'
        end
        @account, @profile = account_id, profile_id
        @collection = collection.with(write: { w: 'majority', j: true }, read: { mode: :primary }, read_concern: { level: :majority })
      end
      def accept(entry)
        unless entry.is_a?(Hash) && entry.keys.sort == (REFERENCE_FIELDS + %w[state attempts]).sort &&
            entry['state'] == 'pending' && entry['attempts'] == 0 &&
            entry['revision'].is_a?(Integer) && entry['revision'].positive? &&
            (REFERENCE_FIELDS - ['revision']).all? { |field| entry[field].is_a?(String) && !entry[field].empty? && entry[field].bytesize <= 200 }
          raise ArgumentError, 'Only a receipt reference and initial pending work may be stored.'
        end
        references = entry.select { |key, _value| REFERENCE_FIELDS.include?(key) }
        scope = { 'account_id' => @account, 'profile_id' => @profile }
        identity = Receiver.digest([@account, @profile, entry.fetch('workspace_id'), entry.fetch('event_id')])
        receipt_digest = Receiver.digest(references.merge(scope))
        document = entry.merge(scope).merge('_id' => identity, 'receipt_digest' => receipt_digest, 'accepted_at' => Time.now.utc)
        begin
          @collection.insert_one(document)
        rescue Mongo::Error::OperationFailure => error
          raise unless error.code == 11000
          original = @collection.find(scope.merge('_id' => identity)).first
          unless original && original['receipt_digest'] == receipt_digest
            raise ProtocolError, 'Redelivery conflicts with the durable receipt.'
          end
        end
        identity
      end
    end
  end
end
