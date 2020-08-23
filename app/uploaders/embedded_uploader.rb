class EmbeddedUploader < BasicUploader

  storage :embedded

  def store_dir
    "/#{model.class.to_s.underscore.gsub('/', '~')}/#{model.id}/#{mounted_as}"
  end

  class << self
    def prepare_model(model)
      model.class_eval do
        field :files, type: Array
      end
    end
  end
end
