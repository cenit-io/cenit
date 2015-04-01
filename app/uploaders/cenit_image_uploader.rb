# encoding: utf-8

class CenitImageUploader <  CenitUploader

  # Add a white list of extensions which are allowed to be uploaded.
  # For images you might use something like this:
  def extension_white_list
    %w(jpg jpeg gif png)
  end

  # Create different versions of your uploaded files:
  version :thumb do
     process :resize_to_fit => [151, 151]
  end

end
