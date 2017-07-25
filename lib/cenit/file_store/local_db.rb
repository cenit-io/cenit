# TODO: Move save a read logic from  Mongoff::GridFs::File.

module Cenit
  module FileStore
    class LocalDb
      class << self
        def label
          'Local DB'
        end

        def save(file, data, options)
          file.save_to_local_db(options)
        end

        def read(file, *args)
          file.read_from_local_db(*args)
        end

        def destroy(file)
          file.destroy_from_local_db
        end
      end
    end
  end
end