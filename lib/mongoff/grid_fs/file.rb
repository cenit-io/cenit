module Mongoff
  module GridFs
    class File < Mongoff::Record

      include FileFormatter

      def initialize(model, document = nil, new_record = true)
        raise "Illegal file model #{model}" unless model.is_a?(FileModel)
        super
        @custom_contentType = false
      end

      def chunk_model
        orm_model.chunk_model
      end

      def data
        if @new_data
          if @new_data.is_a?(String)
            @new_data
          else
            @new_data.rewind
            data = @new_data.read
            @new_data.rewind
            data
          end
        else
          @data ||=
            begin
              data = ''
              chunks.ascending(:n).each { |chunk| data << chunk.data.data }
              data
            end
        end

      end

      def data=(string_or_readable)
        @new_data = string_or_readable
      end

      def []=(field, value)
        @custom_contentType = true if field == :contentType
        super
      end

      def save(options = {})
        self[:metadata] = options[:metadata] || {}
        self[:chunkSize] = FileModel::MINIMUM_CHUNK_SIZE if self[:chunkSize] < FileModel::MINIMUM_CHUNK_SIZE
        temporary_file = nil
        new_chunks_ids =
          if @new_data
            readable =
              if @new_data.is_a?(String)
                temporary_file = Tempfile.new('file_')
                temporary_file.binmode
                temporary_file.write(@new_data)
                temporary_file.rewind
                Cenit::Utility::Proxy.new(temporary_file, original_filename: filename || options[:filename] || options[:default_filename])
              else
                @new_data
              end
            if !options[:valid_data] && (file_data_errors = orm_model.data_type.validate_file(self)).present?
              errors.add(:base, "Invalid file data: #{file_data_errors.to_sentence}")
            else
              create_temporary_chunks(readable, options)
            end
          end
        temporary_file.close if temporary_file
        [:filename, :contentType].each { |property| self[property] = options[property] unless self[property].present? }
        if errors.blank? && super
          if new_chunks_ids
            chunks.delete_many
            chunk_model.all.any_in(id: new_chunks_ids).update_many('$set' => { files_id: id })
          end
        end
        errors.blank?
      end

      def destroy
        chunks.delete_many
        super
      end

      private

      def chunks
        chunk_model.where(files: id)
      end

      def create_temporary_chunks(readable, options)
        new_chunks_ids = []
        temporary_files_id = BSON::ObjectId.new
        md5 = Digest::MD5.new
        length = 0
        n = -1

        reading(readable) do |io|

          unless filename.present?
            self[:filename] = options[:filename] || extract_basename(io) || options[:default_filename] || 'file'
          end
          if contentType = options[:contentType] || extract_content_type(self[:filename]) || options[:default_contentType]
            self[:contentType] = contentType
          end unless @custom_contentType

          chunking(io, chunkSize) do |buf|
            md5 << buf
            length += buf.size
            chunk = chunk_model.new(temporary_files_id)
            chunk.n = n = n + 1
            chunk.data = BSON::Binary.new(buf, :generic)
            if chunk.save
              new_chunks_ids << chunk.id
            else
              #TODO Handle saving chunk error
              raise Exception.new('fail saving chunks')
            end
          end

          self[:length] ||= length
          self[:uploadDate] ||= Time.now.utc
          self[:md5] ||= md5.hexdigest
        end

        new_chunks_ids
      end

      def reading(arg, &block)
        if arg.respond_to?(:read)
          rewind(arg) do |io|
            block.call(io)
          end
        else
          #TODO Open a file...
          # open(arg.to_s) do |io|
          #   block.call(io)
          # end
        end
      end

      def rewind(io, &block)
        begin
          pos = io.pos
          io.flush
          io.rewind
        rescue
        end

        begin
          block.call(io)
        ensure
          begin
            io.pos = pos
          rescue
          end
        end
      end

      def extract_basename(object)
        file_name = nil
        [
          :original_path,
          :original_filename,
          :path,
          :filename,
          :pathname,
          :path,
          :to_path
        ].detect { |msg| object.respond_to?(msg) && file_name = object.send(msg) }
      file_name ? clean(file_name).squeeze('/') : nil
    end

    def extract_content_type(filename)
      if mime_type = MIME::Types.type_for(::File.basename(filename.to_s)).first
        mime_type.to_s
      else
        self[:contentType]
      end
    end

    def clean(path)
      basename = ::File.basename(path.to_s)
      CGI.unescape(basename).gsub(%r/[^0-9a-zA-Z_@)(~.-]/, '_').gsub(%r/_+/, '_')
    end

    def chunking(io, chunk_size, &block)
      if io.method(:read).arity == 0
        data = io.read
        i = 0
        loop do
          offset = i * chunk_size
          length = i + chunk_size < data.size ? chunk_size : data.size - offset

          break if offset >= data.size

          buf = data[offset, length]
          block.call(buf)
          i += 1
        end
      else
        while ((buf = io.read(chunk_size)) && buf.size > 0)
          block.call(buf)
        end
      end
    end
  end
end
end