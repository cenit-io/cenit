module Setup
  class PullImport < Setup::BasePull
    include Setup::DataUploader

    build_in_data_type

    def run(message)
      message[:discard_collection] = true unless message.has_key?(:discard_collection)
      super
    end

    protected

    def source_shared_collection
      @shared_collection ||= Setup::CrossSharedCollection.new(pull_data: hashify(data))
    end
  end
end
