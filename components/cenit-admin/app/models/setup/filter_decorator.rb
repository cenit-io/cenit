module Setup
  Filter.class_eval do
    include RailsAdmin::Models::Setup::FilterAdmin
  end
end
