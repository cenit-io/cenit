class EmbeddedS3Uploader < BasicUploader

  def self.storage_key
    :embedded_s3
  end

  include EmbeddedUploaderBehavior

  def remove!
    storage.try(:clean_up)
    super
  end
end
