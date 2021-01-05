module GridFsFormatter

  def url
    "/file/#{model.class.to_s.underscore.gsub('/', '~')}/#{model.id}/#{mounted_as}/#{identifier}"
  end

  def to_hash(options = {})
    hash = {}
    if present? && file && file.grid_file
      hash[:storage_id] = file.grid_file.id.to_s
      hash[:url] = "#{Cenit.homepage}#{url}"
      versions.each do |key, uploader|
        hash[key] = uploader.to_hash(options)
      end
    end
    hash.stringify_keys
  end
end