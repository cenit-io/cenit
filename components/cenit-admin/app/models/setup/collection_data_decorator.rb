module Setup
  CollectionData.class_eval do
    include RailsAdmin::Models::Setup::CollectionDataAdmin
  end
end
