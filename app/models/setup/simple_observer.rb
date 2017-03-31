module Setup
  class SimpleObserver < Observer
    include RailsAdmin::Models::Setup::SimpleObserverAdmin

    build_in_data_type.referenced_by(:namespace, :name).excluding(:origin)

  end
end
