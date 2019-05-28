module Setup
  Category.class_eval do
    include RailsAdmin::Models::Setup::CategoryAdmin
  end
end
