module Setup
  Collection.class_eval do
    include RailsAdmin::Models::Setup::CollectionAdmin
  end
end
