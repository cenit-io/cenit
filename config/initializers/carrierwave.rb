require 'cenit/account_grid_fs'
require 'cenit/embedded_storage'
require 'cenit/embedded_s3_storage'

CarrierWave.configure do |config|
  config.storage = :grid_fs
  config.root = Rails.root.join('tmp')
  config.cache_storage = :file
  config.cache_dir = "uploads"
  config.grid_fs_access_url = '/file'
  puts config.storage_engines.merge!(
    account_grid_fs: Cenit::AccountGridFs.to_s,
    embedded: Cenit::EmbeddedStorage.to_s,
    embedded_s3: Cenit::EmbeddedS3Storage.to_s
  )
end

Mongoid::GridFs::Cenit::File.defaults.chunkSize = Cenit.storage_chunk_size
Mongoid::GridFs::Cenit::File.fields['chunkSize'].default_val = Cenit.storage_chunk_size