class EmbeddedUploader < BasicUploader

  storage :embedded

  def store_dir
    "/#{model.class.to_s.underscore.gsub('/', '~')}/#{model.id}/#{mounted_as}"
  end

  class << self
    def prepare_model(model)
      model.class_eval do
        field :files, type: Array

        before_save :embed_files

        def embed_files
          if (mounters = instance_variable_get(:@_mounters))
            mounters.each do |field, mounter|
              next unless mounter.uploader.is_a?(EmbeddedUploader)
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
