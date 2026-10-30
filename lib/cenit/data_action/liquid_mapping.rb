require_relative 'receiver'

module Cenit
  module DataAction
    # Explicit, detached input to Cenit's existing template interface. This object
    # has no persistence, identity lookup, selectors or remote model behavior.
    class Document
      def initialize(data)
        raise ArgumentError, 'A document object is required.' unless data.is_a?(Hash)
        @serialized = JSON.generate(data).freeze
      end
      def to_hash(**_options)
        JSON.parse(@serialized)
      end
    end
    class LiquidMapping
      attr_reader :version
      def initialize(template:, code_digest:, version:)
        unless template.is_a?(Setup::LiquidTemplate) && template.persisted? && template.source_data_type.nil? &&
            code_digest.is_a?(String) && code_digest.match?(/\A[0-9a-f]{64}\z/)
          raise ArgumentError, 'A persisted Liquid template without a record model and its pinned digest are required.'
        end
        raise ArgumentError, 'A mapping version is required.' unless version.is_a?(String) && version.bytesize.between?(1, 100)
        @template, @digest, @version = template, code_digest, version
      end
      def digest
        Digest::SHA256.hexdigest(@template.code)
      end
      def call(data)
        unless digest == @digest && @template.source_data_type.nil?
          raise ProtocolError, 'The pinned transformation is unavailable.'
        end
        @template.run(source: Document.new(data))
      end
    end
  end
end
