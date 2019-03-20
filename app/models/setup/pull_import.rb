module Setup
  class PullImport < Setup::BasePull
    include Setup::DataUploader
    include RailsAdmin::Models::Setup::PullImportAdmin

    build_in_data_type

    def run(message)
      message[:discard_collection] = true unless message.has_key?('discard_collection')
      super
    end

    protected

    def source_shared_collection
      unless @shared_collection
        pull_data = hashify(data)
        @shared_collection = Setup::CrossSharedCollection.new(data: pull_data)
        %w(name title readme).each { |key| @shared_collection[key] = pull_data[key] }
      end
      @shared_collection
    end

  end
end
