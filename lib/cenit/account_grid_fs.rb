module Cenit
  class AccountGridFs < CarrierWave::Storage::GridFS
    class File < CarrierWave::Storage::GridFS::File

      def initialize(uploader, path, grid = nil)
        super(uploader, path)
        @_grid = grid
      end

      def grid
        @_grid || super
      end

      self.grid = Mongoid::GridFs.build_namespace_for(Cenit)

      self.grid.file_model.store_in collection: Proc.new { "#{Account.tenant_collection_prefix}.files" }
      self.grid.chunk_model.store_in collection: Proc.new { "#{Account.tenant_collection_prefix}.chunks" }

      def write(file)
        attrs = @uploader.try(:file_attributes) || {}
        attrs[:filename] = @uploader.store_path
        grid.put(file, attrs)
      ensure
        @grid_file = nil
      end

      def delete
        if grid_file
          grid_file.destroy
        end
      end
    end

    def store!(file)
      if (data_type = uploader.model.try(:data_type)).is_a?(Setup::FileDataType)
        data_type.validate_file!(file)
      end
      stored = Cenit::AccountGridFs::File.new(uploader, uploader.store_path, uploader.try(:grid))
      stored.write(file)
      stored
    end

    def retrieve!(identifier)
      Cenit::AccountGridFs::File.new(uploader, uploader.store_path(identifier), uploader.try(:grid))
    end
  end
end