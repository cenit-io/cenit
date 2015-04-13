class CenitImageUploader < CenitUploader
  def extension_white_list
    %w(jpg jpeg gif png)
  end

  version :thumb do
    process :resize_to_fit => [151, 151]
  end

end
