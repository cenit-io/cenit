class EmbeddedUploader < BasicUploader

  storage :embedded

  def store_dir_for(record, field)
    "/#{record.class.to_s.underscore.gsub('/', '~')}/#{record.id}/#{field}"
  end

  def to_hash(_options = {})
    if present?
      url = "file/#{self.url}".squeeze('//')
      {
        url: "#{Cenit.homepage}/#{url}",
        filename: file.filename,
        content_type: file.content_type,
        size: file.size,
        metadata: file.metadata
      }
    else
      {}
    end
  end

  class << self
    def prepare_model(model)
      model.class_eval do

        build_in_data_type.excluding(:files)

        field :files, type: Array

        before_save :embed_files

        def embed_files
          if (mounters = instance_variable_get(:@_mounters))
            mounters.each do |field, mounter|
              next unless mounter.uploaders.any? { |uploader| uploader.is_a?(EmbeddedUploader) }
              i_flag = :"@embedding_#{field}_files"
              instance_variable_set(i_flag, true)
              send("store_#{field}!")
              remove_instance_variable(i_flag)
            end
          end
        end
      end
    end
  end
end
