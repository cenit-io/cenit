module Setup
  DataTypeConfig.class_eval do
    include RailsAdmin::Models::Setup::DataTypeConfigAdmin
  end
end
