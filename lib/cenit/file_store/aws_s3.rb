require 'aws-sdk'

Aws.config[:ssl_verify_peer] = false

module Cenit
  module FileStore
    module AwsS3
      extend Base
      extend AwsS3Default
      extend self

      def label
        'AWS-S3'
      end

      def bucket_name(file)
        "#{Cenit.aws_s3_bucket_prefix}-tenant-#{tenant_id}"
      end

      def object_key(file)
        file.id.to_s
      end
    end
  end
end