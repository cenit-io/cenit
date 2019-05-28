module Setup
  CrossCollectionAuthor.class_eval do
    include RailsAdmin::Models::Setup::CrossCollectionAuthorAdmin
  end
end
