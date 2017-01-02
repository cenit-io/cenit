class BasicUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  def store_dir
    "/#{model.class.to_s.underscore.gsub('/', '~')}/#{mounted_as}/#{model.id}"
  end

  def to_hash(options={})
    hash = { url: "#{Cenit.homepage}#{url}" }
    versions.keys.each do |key|
      hash[key] = "#{Cenit.homepage}#{send(key).url}"
    end
    hash.stringify_keys
  end
end
