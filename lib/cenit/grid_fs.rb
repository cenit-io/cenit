module Cenit
  class GridFs < CarrierWave::Storage::GridFS
    class File < CarrierWave::Storage::GridFS::File
      self.grid = Mongoid::GridFs.build_namespace_for(Cenit)

      self.grid.file_model.store_in collection: Proc.new { "acc#{Account.current.id}.files" }
      self.grid.chunk_model.store_in collection: Proc.new { "acc#{Account.current.id}.chunks" }
    end

    def store!(file)
      stored = Cenit::GridFs::File.new(uploader, uploader.store_path)
      stored.write(file)
      stored
    end

    def retrieve!(identifier)
      Cenit::GridFs::File.new(uploader, uploader.store_path(identifier))
    end
  end
end