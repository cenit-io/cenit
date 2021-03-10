module GridFsFormatter

  def default_url
    "/file/#{model.class.to_s.underscore.gsub('/', '~')}/#{model.id}/#{mounted_as}/#{identifier}"
  end

  def to_hash(options = {})
    hash = {}
    if present? && file && (f = file.grid_file)
      hash[:storage_id] = f.id.to_s
      hash[:url] = "#{Cenit.homepage}#{url}"
      hash[:filename] = f.filename.split('/').pop
      hash[:content_type] = f.content_type
      hash[:size] = f.length
      hash[:metadata] = f.metadata
      versions.each do |key, uploader|
        hash[key] = uploader.to_hash(options)
      end
    end
    hash.stringify_keys
  end
end