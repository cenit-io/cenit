class BasicUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  def store_dir
    "/#{model.class.to_s.underscore.gsub('/', '~')}/#{mounted_as}/#{model.id}"
  end

  def filename
    if original_filename.present?
      md5 = Digest::MD5.new
      md5 << super
      md5.hexdigest + file_extension
    end
  end

  def file_extension
    if original_filename.present?
      File.extname(original_filename)
    else
      nil
    end
  end
end
