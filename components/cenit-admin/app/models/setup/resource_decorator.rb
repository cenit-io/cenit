module Setup
  Resource.class_eval do
    include RailsAdmin::Models::Setup::ResourceAdmin
  end
end
