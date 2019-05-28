module Setup
  DataTypeExpansion.class_eval do
    include RailsAdmin::Models::Setup::DataTypeExpansionAdmin
  end
end
