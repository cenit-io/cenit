module Setup
  class ApiPull < Setup::BasePull
    include PullingField

    build_in_data_type

    pulling :api, class: Setup::Api

    def source_shared_collection
      unless @shared_collection
        pull_data = api.cenit_collection_hash(task: self)
        @shared_collection= Setup::CrossSharedCollection.new(pull_data: pull_data)
        %w(name title readme).each { |key| @shared_collection[key] = pull_data[key] }
      end
      @shared_collection
    end

    def run(message)
      fail 'No API to pull' unless api
      super
    end
  end
end
