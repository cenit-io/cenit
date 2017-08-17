module Mongoff
  module GridFs
    class File < Mongoff::Record

      include FileFormatter

      def initialize(model, document = nil, new_record = true)
        raise "Illegal file model #{model}" unless model.is_a?(FileModel)
        super
        @cursor = 0
      end

      def to_s
        filename
      end

      def chunk_model
        orm_model.chunk_model
      end

      def rewind
        @cursor = 0
        @new_data.try(:rewind)
      end

      def read(*args)
        len = (args.length > 0 && args[0].to_i) || length || 0
        if @new_data
          if @new_data.is_a?(String)
            return nil if @cursor == @new_data.length
            start = @cursor
            if len > @new_data.length - start
              len = @new_data.length - start
            end
            @cursor += len
            @new_data[start, len]
          else
            @new_data.read(len)
          end
        else
          return nil if @cursor == length
          current_chunk = @cursor / chunkSize
          chunk_start = @cursor - current_chunk * chunkSize
          chunk_chunk = chunkSize - chunk_start
          if chunk_chunk > len
            chunk_chunk = len
          end
          chunks_left = ((len - chunk_chunk) / chunkSize.to_f).ceil
          data = ''
          chunks.ascending(:n).where(:n.gte => current_chunk,
                                     :n.lte => current_chunk + chunks_left).each do |chunk|
            data += chunk.data.data[chunk_start, chunk_chunk]
            if (chunk_chunk = len - data.length) > chunkSize
              chunk_chunk = chunkSize
            end
            chunk_start = 0
          end
          @cursor += data.length
          data
        end
      end

      def data
        rewind
        read
      end

      def data=(string_or_readable)
        @cursor = 0
        if (@new_data = string_or_readable)
          self.length = @new_data.size
        end
      end

      attr_accessor :encoding

      def [](field)
        field = field.to_s.to_sym
        case field
        when :data
          data
        when :encoding
          encoding
        else
          super
        end
      end

      def []=(field, value)
        field = field.to_s.to_sym
        case field
        when :data
          self.data = value
        when :encoding
          self.encoding = value
        else
          value = super
          case field
          when :filename
            @custom_filename = value
          when :contentType
            @custom_content_type = value
          end
        end
      end

      def decode(data)
        case encoding
        when 'base64', 'strict_base64', 'urlsafe_base64'
          Base64.send(encoding.gsub('base', 'decode'), data)
        else
          data
        end
      end

      def save(options = {})
        if (value = options[:metadata])
          self[:metadata] = value
        else
          self[:metadata] ||= {}
        end
        if (value = options[:encoding])
          self.encoding = value
        end
        self[:chunkSize] = FileModel::MINIMUM_CHUNK_SIZE if self[:chunkSize] < FileModel::MINIMUM_CHUNK_SIZE
        run_callbacks_and do
          temporary_file = nil
          new_chunks_ids =
            if @new_data
              readable =
                if @new_data.is_a?(String)
                  ext =
                    if (content_type = options[:content_type] || self.contentType) &&
                      (types = MIME::Types[content_type]).present? &&
                      (type = types.detect { |t| t.extensions.present? })
                      type.extensions.first
                    else
                      ''
                    end
                  temporary_file = Tempfile.new(['file_', ".#{ext}"])
                  temporary_file.binmode
                  temporary_file.write(decode(@new_data))
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
            else
              errors.add(:data, "can't be nil") if new_record?
            end
          temporary_file.close if temporary_file
          [:filename, :contentType].each { |property| self[property] = options[property] unless self[property].present? }
          if errors.blank? && super
            @cursor = 0
            if new_chunks_ids
              chunks.delete_many
              chunk_model.all.any_in(id: new_chunks_ids).update_many('$set' => { files_id: id })
            end
          end
        end
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

          unless @custom_filename
            self[:filename] = options[:filename] || extract_basename(io) || self[:filename] || options[:default_filename] || 'file'
          end
          unless @custom_content_type
            self[:contentType] = options[:contentType] || extract_content_type_from_io(io) || extract_content_type(self[:filename]) || options[:default_contentType]
          end

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

          self[:length] = length
          self[:uploadDate] ||= Time.now.utc
          self[:md5] = md5.hexdigest
        end

        new_chunks_ids
      end

      def reading(arg, &block)
        if arg.respond_to?(:read)
          do_rewind(arg) do |io|
            block.call(io)
          end
        else
          #TODO Open a file...
          # open(arg.to_s) do |io|
          #   block.call(io)
          # end
        end
      end

      def do_rewind(io, &block)
        begin
          pos = io.pos
          io.flush
        rescue
        end

        begin
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
        ].detect { |msg| object.respond_to?(msg) && (file_name = object.send(msg)) }
        file_name ? clean(file_name).squeeze('/') : nil
      end

      def extract_content_type_from_io(io)
        content_type= nil
        [
          :content_type,
          :contentType
        ].detect { |msg| object.respond_to?(msg) && (content_type = object.send(msg)) }
        content_type ? clean(content_type).squeeze('/') : nil
      end

      def extract_content_type(filename)
        if (mime_type = MIME::Types.type_for(::File.basename(filename.to_s)).first)
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
          while (buf = io.read(chunk_size)) && buf.size > 0
            block.call(buf)
          end
        end
      end
    end
  end
end