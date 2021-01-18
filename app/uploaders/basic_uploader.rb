class BasicUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  def store_dir
    store_dir_for(model, mounted_as)
  end

  def store_dir_for(record, field)
    "/#{record.class.to_s.underscore.gsub('/', '~')}/#{field}/#{record.id}"
  end

  def path_for(record, field, filename)
    "#{store_dir_for(record, field)}/#{filename}"
  end

  attr_accessor :file_attributes
end
