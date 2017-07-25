require 'aws-sdk'

Aws.config[:ssl_verify_peer] = false

module Cenit
  module FileStore
    class AwsS3
      class << self
        def label
          'AWS-S3'
        end

        def client
          @client ||= Aws::S3::Client.new(
            region: 'us-west-2',
          # access_key_id: ENV['AWS_ACCESS_KEY_ID'],
          # secret_access_key:  ENV['AWS_SECRET_ACCESS_KEY']
          )
        end

        def save(file, data, options)
          opts = {
            :content_type => file[:contentType],
            :metadata => {
              :filename => file[:filename],
            }
          }

          resource = Aws::S3::Resource.new(client: client)
          obj = resource.bucket('cenit-io').object(file.id.to_s)
          data.is_a?(String) ? obj.put(opts.merge(body: data)) : obj.upload_file(data.path, opts)
        end

        def read(file, *args)
          obj = client.get_object(bucket: 'cenit-io', key: file.id.to_s)
          obj.body.read
        rescue Exception => ex
          nil
        end

        def destroy(file)
          obj = client.get_object(bucket: 'cenit-io', key: file.id.to_s)
          obj.delete
        rescue Aws::S3::Errors::NoSuchKey => ex
          # The file no longer exists.
        end
      end
    end
  end
end