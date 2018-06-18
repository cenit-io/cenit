require 'aws-sdk'

Aws.config[:ssl_verify_peer] = false

module Cenit
  module FileStore
    module AwsS3Default
      extend Base
      extend self

      def label
        'AWS-S3-Default'
      end

      ###
      # Save file content.
      def save(file, data, options)
        file.instance_variable_set(:@_store_io, nil)
        opts = {
          content_type: file[:contentType],
          metadata: {
            filename: file[:filename]
          }
        }

        object(file) do |obj|
          if data.is_a?(String)
            obj.put(opts.merge(body: data))
          else
            obj.upload_file(data.path, opts)
          end
        end
      end

      ###
      # Read file content.
      def read_from_store(file, len)
        unless (store_io = file.instance_variable_get(:@_store_io))
          store_io = object(file) do |obj|
            if obj.exists?
              obj.get.body
            else
              StringIO.new
            end
          end
          file.instance_variable_set(:@_store_io, store_io)
        end
        store_io.seek(file.cursor)
        store_io.read(len)
      end

      ###
      # Remove file from amazon
      def destroy(file)
        file.instance_variable_set(:@_store_io, nil)
        object(file) { |obj| obj.delete if obj.exists? }
      end

      ###
      # Returns client connection.
      def client
        @client ||= Aws::S3::Client.new(
          region: Cenit.aws_s3_region,
        # access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        # secret_access_key:  ENV['AWS_SECRET_ACCESS_KEY']
          )
      end

      ###
      # Returns bucket reference for current tenant.
      def bucket(file)
        @resource ||= Aws::S3::Resource.new(client: client)
        _bucket = @resource.bucket(bucket_name(file))
        _bucket.create unless _bucket.exists?
        _bucket
      end

      def bucket_name(file)
        "#{Cenit.aws_s3_bucket_prefix}"
      end

      ###
      # Returns file object reference for current tenant.
      def object(file, &block)
        block.call(bucket(file).object(file_id(file)))
      end

      def file_id(file)
        tenant_id = Account.current ? Account.current.id.to_s : :default
        Digest::MD5.hexdigest("#{tenant_id}-#{file.orm_model.data_type.id}-#{file.id}")
      end
    end
  end
end