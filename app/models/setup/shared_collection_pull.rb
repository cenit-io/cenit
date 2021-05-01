module Setup
  class SharedCollectionPull < Setup::BasePull
    include PullingField

    agent_field :shared_collection

    build_in_data_type

    pulling :shared_collection, class: Setup::CrossSharedCollection

    def source_shared_collection
      shared_collection
    end

    def run(message)
      fail 'No shared collection to pull' unless source_shared_collection
      super
    end

    protected

    def ask_for_install?
      ::User.super_access? && !shared_collection.installed?
    end

  end
end
