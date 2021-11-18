class EmbeddedUploader < BasicUploader
  include EmbeddedUploaderBehavior

  def self.storage_key
    :embedded
  end
end
