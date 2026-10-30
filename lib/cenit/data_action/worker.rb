require_relative 'receiver'
require_relative 'delivery_errors'

module Cenit
  module DataAction
    class Worker
      def initialize(inbox:, client:, mapping:, connector:)
        @inbox, @client, @mapping, @connector = inbox, client, mapping, connector
      end
      def run_once
        job = @inbox.claim
        return false unless job
        begin
          configuration_current = begin
            job['mapping_version'] == @mapping.version && job['mapping_digest'] == @mapping.digest && job['connector_digest'] == @connector.digest
          rescue ArgumentError
            false
          end
          unless configuration_current
            raise DeliveryFailure.new('CONFIGURATION_CHANGED', retryable: false)
          end
          result = @client.query(job.fetch('query_version_id'), record_id: job.fetch('record_id'), revision: job.fetch('revision'))
          records = result.is_a?(Hash) && result['records']
          record = records.is_a?(Array) && records.size == 1 && records.first
          unless record.is_a?(Hash) && record['id'] == job['record_id'] && record['revision'] == job['revision'] &&
              record['workspaceId'] == job['workspace_id'] && record['typeId'] == job['object_type_version_id'] &&
              record['data'].is_a?(Hash) && Receiver.digest(record['data']) == job['data_digest']
            raise DeliveryFailure.new('REVISION_UNAVAILABLE', retryable: false)
          end
          body = @mapping.call(record.fetch('data'))
          unless body.is_a?(String) && body.bytesize <= 64_000
            raise DeliveryFailure.new('INVALID_TRANSFORMATION', retryable: false)
          end
          # Recheck the local fence before any external effect; the sink must also
          # deduplicate because no local lease can fence an already running HTTP call.
          @inbox.renew(job.fetch('_id'), fence: job.fetch('fence'))
          receipt = @connector.lookup(job.fetch('effect_key'))
          receipt ||= @connector.deliver(job.fetch('effect_key'), body)
          unless receipt.is_a?(Hash) && receipt.keys.sort == %w[bodyDigest effectKey receiptId] &&
              receipt['effectKey'] == job['effect_key'] && receipt['bodyDigest'] == Digest::SHA256.hexdigest(body) &&
              receipt['receiptId'].is_a?(String) && receipt['receiptId'].bytesize.between?(1, 200)
            raise DeliveryFailure.new('RECEIPT_CONFLICT', retryable: false)
          end
          @inbox.complete(job.fetch('_id'), fence: job.fetch('fence'), receipt: receipt)
        rescue StaleWorkLease
          # A newer worker owns recovery. Never change its state with an old fence.
        rescue DeliveryFailure => error
          fail_current(job.fetch('_id'), fence: job.fetch('fence'), code: error.code, retryable: error.retryable)
        rescue TransportError
          fail_current(job.fetch('_id'), fence: job.fetch('fence'), code: 'SOURCE_UNAVAILABLE', retryable: true)
        rescue RequestError => error
          fail_current(job.fetch('_id'), fence: job.fetch('fence'), code: 'SOURCE_REQUEST_FAILED', retryable: error.status >= 500 || [401, 403, 429].include?(error.status))
        rescue ProtocolError, JSON::ParserError
          fail_current(job.fetch('_id'), fence: job.fetch('fence'), code: 'INVALID_CONTRACT', retryable: false)
        end
        true
      end
      private
      def fail_current(id, **failure)
        @inbox.fail(id, **failure)
      rescue StaleWorkLease
        # A failed HTTP call may return after another worker reclaimed its lease.
      end
    end
  end
end
