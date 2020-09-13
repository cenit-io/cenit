module Cenit
  class EmbeddedStorage < CarrierWave::Storage::Abstract

    def store!(file)
      record = uploader.model
      unless (files = record.files)
        files = record.files = []
      end
      unless (index = files.find_index { |f| f.filename == file.indentifier })
        index = files.length
        files << {}
      end
      files[index].merge!(
        filename: file.filename,
        content_type: file.content_type.presence ||
          MIME::Types.type_for(file.filename)[0].to_s.presence ||
          'application/octet-stream',
        data: BSON::Binary.new(file.read)
      )
      record.save
    end

    def retrieve!(identifier)
      file = (uploader.model.files || []).detect { |f| f[:filename] == identifier }
      file && File.new(
        tempfile: StringIO.new(file[:data].data),
        filename: identifier,
        content_type: file[:content_type],
        uploader: uploader
      )
    end

    class File < ::CarrierWave::SanitizedFile

      def initialize(attrs)
        @uploader = attrs.delete(:uploader)
        super
      end

      def path
        "#{@uploader.store_dir}/#{filename}"
      end
    end
  end
end