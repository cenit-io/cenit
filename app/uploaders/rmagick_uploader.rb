module RmagickUploader
  extend ActiveSupport::Concern

  included do
    process resize_to_fit: [300, 300], convert: :jpg

    version :thumb do
      process resize_to_fit: [151, 151]
    end

    version :icon do
      process resize_to_fit: [32, 32]
    end
  end

  def extension_white_list
    %w(jpg jpeg gif png)
  end
end