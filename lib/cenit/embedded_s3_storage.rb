module Cenit
  class EmbeddedS3Storage < EmbeddedStorage

    def clean_up
      obj = self.class.bucket.object(
        self.class.object_key(uploader.model, uploader.file&.filename)
      )
      if obj.exists?
        obj.delete
      end
    end

    def get_data_for(record, file)
      obj = self.class.bucket.object(
        self.class.object_key(record, file[:filename])
      )
      if obj.exists?
        obj.get.body
      else
        StringIO.new
      end
    end

    class << self

      def embeds_data_for(embedded, file, record)
        bucket.object(
          object_key(record, file.identifier)
        ).put(
          content_type: embedded[:content_type],
          body: file.read
        )
      end

      def tenant_id
        ::Account.current ? ::Account.current.id.to_s : :default
      end

      def object_key(record, filename)
        "#{record.orm_model.to_s.underscore}/#{tenant_id}/#{record.id}/#{filename}"
      end

      def public_url(record, file)
        "https://s3-#{Cenit.aws_s3_region}.amazonaws.com/#{bucket_name}/#{object_key(record, file)}"
      end

      def bucket_name
        "#{Cenit.aws_s3_bucket_prefix}"
      end

      def bucket
        unless @bucket
          @bucket = FileStore::AwsS3Default.resource.bucket(bucket_name)
          @bucket.create unless @bucket.exists?
        end
        @bucket
      end
    end
  end
end