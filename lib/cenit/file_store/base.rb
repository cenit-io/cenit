module Cenit
  module FileStore
    module Base
      extend self

      def label
        fail NotImplementedError
      end

      def save(file, data, options)
        fail NotImplementedError
      end

      def read(file, *args)
        len = (args.length.positive? && args[0].to_i) || file.length || 0
        if (stash_data = file.stash_data)
          if stash_data.is_a?(String)
            cursor = file.cursor
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
          data = read_from_store(file, len)
          file.seek(file.cursor + (data ? data.length : 0))
          data
        end
      end

      def read_from_store(file, len)
        fail NotImplementedError
      end

      def destroy(file)
        fail NotImplementedError
      end

      def set_public_read(file, status)

      end

      def public_url(file)

      end

      def stored?(file)
        fail NotImplementedError
      end
    end
  end
end