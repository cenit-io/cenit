require 'cenit/grid_fs'

CarrierWave.configure do |config|
  config.storage = :grid_fs
  config.root = Rails.root.join('tmp')
  config.cache_dir = "uploads"
  config.grid_fs_access_url = '/file'
  puts config.storage_engines.merge! cenit_grid_fs: Cenit::GridFs.to_s
end