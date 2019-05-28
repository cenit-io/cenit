module Setup
  CrossSharedCollection.class_eval do
    include RailsAdmin::Models::Setup::CrossSharedCollectionAdmin
  end
end
