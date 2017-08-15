module Cenit
  module FileStore
    class LocalDb
      class << self

        def label
          'Local DB'
        end

        def save(file, data, options)
          file[:chunkSize] = [[file[:chunkSize], Mongoff::GridFs::FileModel::MINIMUM_CHUNK_SIZE].max, Mongoff::GridFs::FileModel::MAXIMUM_CHUNK_SIZE].min
          temporary_file = nil
          readable =
            if data.is_a?(String)
              ext =
                if (content_type = options[:content_type] || file.contentType) &&
                  (types = MIME::Types[content_type]).present? &&
                  (type = types.detect { |t| t.extensions.present? })
                  type.extensions.first
                else
                  ''
                end
              temporary_file = Tempfile.new(['file_', ".#{ext}"])
              temporary_file.binmode
              temporary_file.write(file.decode(data))
              temporary_file.rewind
              Cenit::Utility::Proxy.new(temporary_file, original_filename: file.filename || options[:filename] || options[:default_filename])
            else
              data
            end
          new_chunks_ids = create_temporary_chunks(file, readable)
          temporary_file.close if temporary_file
          file.seek(0)
          chunks(file).delete_many
          chunk_model(file).all.any_in(id: new_chunks_ids).update_many('$set' => { files_id: file.id })
        end

        def read(file, *args)
          len = (args.length > 0 && args[0].to_i) || file.length || 0
          cursor = file.cursor
          if (stash_data = file.stash_data)
            if stash_data.is_a?(String)
              return nil if cursor == stash_data.length
              start = cursor
              if len > stash_data.length - start
                len = stash_data.length - start
              end
              file.seek(cursor + len)
              stash_data[start, len]
            else
              stash_data.read(len)
            end
          else
            return nil if cursor == file.length
            chunk_size = file[:chunkSize]
            current_chunk = cursor / chunk_size
            chunk_start = cursor - current_chunk * chunk_size
            chunk_chunk = chunk_size - chunk_start
            if chunk_chunk > len
              chunk_chunk = len
            end
            chunks_left = ((len - chunk_chunk) / chunk_size.to_f).ceil
            data = ''
            chunks(file).ascending(:n).where(:n.gte => current_chunk,
                                             :n.lte => current_chunk + chunks_left).each do |chunk|
              data += chunk.data.data[chunk_start, chunk_chunk]
              if (chunk_chunk = len - data.length) > chunk_size
                chunk_chunk = chunk_size
              end
              chunk_start = 0
            end
            file.seek(cursor + data.length)
            data
          end
        end

        def destroy(file)
          chunks(file).delete_many
        end

        def chunks(file)
          chunk_model(file).where(files: file.id)
        end

        def chunk_model(file)
          file.orm_model.chunk_model
        end

        private

        def create_temporary_chunks(file, readable)
          chunk_model = chunk_model(file)
          new_chunks_ids = []
          temporary_files_id = BSON::ObjectId.new
          md5 = Digest::MD5.new
          length = 0
          n = -1

          reading(readable) do |io|

            chunking(io, file[:chunkSize]) do |buf|
              md5 << buf
              length += buf.size
              chunk = chunk_model.new(temporary_files_id)
              chunk.n = n = n + 1
              chunk.data = BSON::Binary.new(buf, :generic)
              if chunk.save
                new_chunks_ids << chunk.id
              else
                chunk_model.any_in(id: new_chunks_ids).delete_many
                fail "error saving chunk ##{n}: #{chunk.errors.full_messages.to_sentence}"
              end
            end

            file[:length] = length
            file[:md5] = md5.hexdigest
          end

          new_chunks_ids
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
      end
    end
  end
end