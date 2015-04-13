class BasicUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  def store_dir
    "/#{model.class.to_s.underscore.gsub('/', '~')}/#{mounted_as}/#{model.id}"
  end
end
