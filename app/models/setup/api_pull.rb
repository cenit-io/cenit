module Setup
  class ApiPull < Setup::BasePull
    include PullingField
    include HashField
    include RailsAdmin::Models::Setup::ApiPullAdmin

    agent_field :api

    build_in_data_type

    pulling :api, class: Setup::ApiSpec
    hash_field :collection_data

    def source_shared_collection
      unless @shared_collection
        unless collection_data.present?
          self.collection_data = api.cenit_collection_hash(task: self)
        end
        @shared_collection = Setup::CrossSharedCollection.new(data: collection_data)
        %w(name title readme).each { |key| @shared_collection[key] = collection_data[key] }
      end
      @shared_collection
    end

    def run(message)
      fail 'No API to pull' unless api
      super
    end

  end
end
